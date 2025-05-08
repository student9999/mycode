module axis_2_axi #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 512,
  parameter ID_WIDTH   = 4,
  parameter BUFFER_DEPTH = 2048
)(
  input  logic clk,
  input  logic rst,
  input  logic [DATA_WIDTH-1:0] s_axis_tdata,
  input  logic s_axis_tvalid,
  output logic s_axis_tready,
  input  logic s_axis_tlast,
  output logic [ID_WIDTH-1:0] m_axi_awid,
  output logic [ADDR_WIDTH-1:0] m_axi_awaddr,
  output logic [7:0] m_axi_awlen,
  output logic [2:0] m_axi_awsize,
  output logic [1:0] m_axi_awburst,
  output logic m_axi_awvalid,
  input  logic m_axi_awready,
  output logic [DATA_WIDTH-1:0] m_axi_wdata,
  output logic [(DATA_WIDTH/8)-1:0] m_axi_wstrb,
  output logic m_axi_wlast,
  output logic m_axi_wvalid,
  input  logic m_axi_wready,
  input  logic [ID_WIDTH-1:0] m_axi_bid,
  input  logic [1:0] m_axi_bresp,
  input  logic m_axi_bvalid,
  output logic m_axi_bready
);

localparam BEAT_BYTES = DATA_WIDTH / 8;
localparam BUFFER_WORDS = BUFFER_DEPTH / BEAT_BYTES;
localparam SIZE_CODE = $clog2(BEAT_BYTES);

typedef enum logic [1:0] {
  TX_IDLE,
  TX_ADDR, //AXI address phase
  TX_DATA, //AXI data phase
  TX_RESP  //AXI response phase
  } tx_state_t;

tx_state_t tx_state = TX_IDLE;
logic pld_valid;
logic [$clog2(BUFFER_WORDS)-1:0] rx_wr_ptr;
logic [15:0] packet_len;

logic [DATA_WIDTH-1:0] buffer0 [0:BUFFER_WORDS-1];
logic [DATA_WIDTH-1:0] buffer1 [0:BUFFER_WORDS-1];
logic [DATA_WIDTH-1:0] buffer0_dout;
logic [DATA_WIDTH-1:0] buffer1_dout;
logic wr_buf_sel; //0 = selected buffer0, 1 = selected buffer1
logic rd_buf_sel;

logic packet_ready;

logic [15:0] total_length_field;
assign total_length_field = {s_axis_tdata[135:128], s_axis_tdata[143:136]};

assign s_axis_tready = pld_valid || !packet_ready || rd_buf_sel != wr_buf_sel;

//receive packets from the AXI stream interface
//back to back packets are supported
//address cycle and data cycle are combined
always_ff @(posedge clk)
 if (rst) begin
  pld_valid <= '0;
  rx_wr_ptr <= '0;
  packet_ready <= '0;
  wr_buf_sel <= '0;
  rd_buf_sel <= '0;
end else begin
  if (s_axis_tvalid && s_axis_tready) begin
    if (~wr_buf_sel)
      buffer0[rx_wr_ptr] <= s_axis_tdata;
    else
      buffer1[rx_wr_ptr] <= s_axis_tdata;
    if (s_axis_tlast) begin
      wr_buf_sel <= ~wr_buf_sel;
      rx_wr_ptr <= '0;
      packet_ready <= 1;
      rd_buf_sel <= wr_buf_sel; //set read buffer to the one just written
      pld_valid <= '0;
    end else begin //if there is still more data to write
      rx_wr_ptr <= rx_wr_ptr+1;
      pld_valid <= 1;
    end
    //store the length of the packet during the header phase
    if (~pld_valid)
      packet_len <= total_length_field;
  end 
  //clear the packet_ready flag when the buffer is read
  if (TX_RESP==tx_state && m_axi_bvalid)
    packet_ready <= 0;
  end

logic [$clog2(BUFFER_WORDS)-1:0] tx_rd_ptr;
logic [15:0] tx_byte_cnt;
logic [ADDR_WIDTH-1:0] ddr_wr_addr;

logic wvalid_stage1;
logic tx_data_cmpl;

assign m_axi_awid     = '0;
assign m_axi_awburst  = 2'b01;
assign m_axi_awsize   = SIZE_CODE;
assign m_axi_bready   = 1;
assign tx_data_cmpl = tx_byte_cnt+BEAT_BYTES >= packet_len;

always_ff @(posedge clk) begin
  if (rst) begin
    tx_state <= TX_IDLE;
    m_axi_awvalid <= '0;
    m_axi_wvalid <= '0;
    m_axi_wlast <= '0;
    m_axi_awlen <= '0;
    tx_byte_cnt <= '0;
    tx_rd_ptr <= '0;
    ddr_wr_addr <= '0;
    wvalid_stage1 <= '0;
    m_axi_wstrb <= '0;
  end else case (tx_state)
    TX_IDLE: if (packet_ready && rd_buf_sel != wr_buf_sel) begin
      m_axi_awvalid <= 1;
      m_axi_awlen   <= (packet_len + BEAT_BYTES - 1) / BEAT_BYTES - 1;
      tx_state <= m_axi_awready ? TX_DATA : TX_ADDR; //skip to TX_DATA state if the address is accepted
      tx_rd_ptr <= 0;
    end
    TX_ADDR: if (m_axi_awready) begin //once the address is accepted start the data phase
      m_axi_awvalid <= 0;
      tx_state <= TX_DATA;
    end
    TX_DATA: begin
      wvalid_stage1 <= m_axi_wready; //add delay to wait for buffer data
      m_axi_wvalid <= wvalid_stage1;
      if (wvalid_stage1) begin               
        if (tx_data_cmpl)
          tx_state <= TX_RESP;
        else
          tx_byte_cnt <= tx_byte_cnt + BEAT_BYTES;
        m_axi_wlast <= tx_data_cmpl;
        m_axi_wstrb <= tx_data_cmpl ?{(DATA_WIDTH/8){1'b1}} >> (BEAT_BYTES - (packet_len - tx_byte_cnt)) : '1;
      end
      if (m_axi_wready)
        tx_rd_ptr <= tx_rd_ptr + 1;        
      end
    TX_RESP: begin
      if (m_axi_bvalid) begin
        tx_state <= TX_IDLE;
        ddr_wr_addr <= ddr_wr_addr + ((packet_len + BEAT_BYTES - 1) / BEAT_BYTES) * BEAT_BYTES;
      end
      wvalid_stage1 <= '0;
      m_axi_wvalid <= '0;
      tx_rd_ptr <='0;
      tx_byte_cnt <= 0;
      m_axi_wlast <= '0;
    end
  endcase
  //RAM latency = 2
  buffer0_dout <= buffer0[tx_rd_ptr];
  buffer1_dout <= buffer1[tx_rd_ptr];
  m_axi_wdata <= ~rd_buf_sel ? buffer0_dout : buffer1_dout;
  //To make timing easier
  m_axi_awaddr  <= ddr_wr_addr;
end


endmodule
