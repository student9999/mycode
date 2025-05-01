module axis_ipv4_to_axi4_writer #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 512,
  parameter ID_WIDTH   = 4,
  parameter BUFFER_DEPTH = 2048
)(
  input  logic clk,
  input  logic rst_n,
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
  output logic m_axi_bready,
  input  logic [ADDR_WIDTH-1:0] base_addr
);

localparam BEAT_BYTES = DATA_WIDTH / 8;
localparam BUFFER_WORDS = BUFFER_DEPTH / BEAT_BYTES;
localparam SIZE_CODE = $clog2(BEAT_BYTES);

typedef enum logic [1:0] {RX_IDLE, RX_STORE} rx_state_t;
typedef enum logic [1:0] {TX_IDLE, TX_ADDR, TX_DATA, TX_RESP} tx_state_t;

rx_state_t rx_state = RX_IDLE;
tx_state_t tx_state = TX_IDLE;
logic [$clog2(BUFFER_WORDS)-1:0] rx_wr_ptr = 0;
logic [15:0] rx_packet_len = 0;
logic [15:0] rx_byte_cnt = 0;

logic [DATA_WIDTH-1:0] buffer0 [0:BUFFER_WORDS-1];
logic [DATA_WIDTH-1:0] buffer1 [0:BUFFER_WORDS-1];
logic active_buf_sel = 0;

logic packet_ready = 0;
logic [15:0] packet_len_saved = 0;
logic tx_buf_sel = 0;

logic [15:0] total_length_field;
assign total_length_field = {s_axis_tdata[135:128], s_axis_tdata[143:136]};

assign s_axis_tready = rx_state != RX_IDLE || !packet_ready || tx_buf_sel != active_buf_sel;

always_ff @(posedge clk or negedge rst_n) if (!rst_n) begin
  rx_state <= RX_IDLE;
  rx_wr_ptr <= 0;
  rx_packet_len <= 0;
  rx_byte_cnt <= 0;
  packet_ready <= 0;
end else begin case (rx_state)
  RX_IDLE: if (s_axis_tvalid && s_axis_tready) begin
    rx_packet_len <= total_length_field;
    rx_wr_ptr <= 0;
    rx_byte_cnt <= BEAT_BYTES;
    if (~active_buf_sel)
      buffer0[0] <= s_axis_tdata;
    else
      buffer1[0] <= s_axis_tdata;
    rx_state <= RX_STORE;
  end
  RX_STORE: if (s_axis_tvalid && s_axis_tready) begin
    rx_wr_ptr <= rx_wr_ptr + 1;
    rx_byte_cnt <= rx_byte_cnt + BEAT_BYTES;
    if (~active_buf_sel)
      buffer0[rx_wr_ptr + 1] <= s_axis_tdata;
    else
      buffer1[rx_wr_ptr + 1] <= s_axis_tdata;
    if (s_axis_tlast) begin
      packet_ready <= 1;
      packet_len_saved <= rx_packet_len;
      tx_buf_sel <= active_buf_sel;
      active_buf_sel <= ~active_buf_sel;
      rx_state <= RX_IDLE;
    end
  end
  endcase
  if (TX_RESP==tx_state && m_axi_bvalid)
    packet_ready <= 0;
end

logic [$clog2(BUFFER_WORDS)-1:0] tx_rd_ptr = 0;
logic [15:0] tx_byte_cnt = 0;
logic [ADDR_WIDTH-1:0] tx_addr = 0;

logic [DATA_WIDTH-1:0] tx_data_stage1 = 0;
logic [DATA_WIDTH-1:0] tx_data_stage2 = 0;

assign m_axi_awid     = '0;
assign m_axi_awburst  = 2'b01;
assign m_axi_awsize   = SIZE_CODE;
assign m_axi_bready   = 1;

always_ff @(posedge clk or negedge rst_n) if (!rst_n) begin
  tx_state <= TX_IDLE;
  m_axi_awvalid <= 0;
  m_axi_wvalid  <= 0;
  m_axi_wlast   <= 0;
  m_axi_awaddr  <= 0;
  tx_byte_cnt   <= 0;
  tx_rd_ptr     <= 0;
  tx_addr       <= base_addr;
  tx_data_stage1 <= 0;
  tx_data_stage2 <= 0;
end else case (tx_state)
  TX_IDLE: if (packet_ready && tx_buf_sel != active_buf_sel) begin
    m_axi_awvalid <= 1;
    m_axi_awaddr  <= tx_addr;
    m_axi_awlen   <= (packet_len_saved + BEAT_BYTES - 1) / BEAT_BYTES - 1;
    tx_data_stage1 <= ~tx_buf_sel ? buffer0[0] : buffer1[0];
    m_axi_wvalid <= 0;
    tx_state <= m_axi_awready ? TX_DATA : TX_ADDR;
    tx_byte_cnt <= BEAT_BYTES;
    tx_rd_ptr <= 1;
  end
  TX_ADDR: if (m_axi_awready) begin
    m_axi_awvalid <= 0;
    tx_state <= TX_DATA;
  end
  TX_DATA: begin
    if (m_axi_wready) begin
      m_axi_wdata <= tx_data_stage2;
      m_axi_wvalid <= 1;
      m_axi_wlast <= packet_len_saved - tx_byte_cnt <= BEAT_BYTES;
      m_axi_wstrb <= packet_len_saved - tx_byte_cnt <= BEAT_BYTES ?
                     {(DATA_WIDTH/8){1'b1}} >> (BEAT_BYTES - (packet_len_saved - tx_byte_cnt)) : '1;
      tx_byte_cnt <= tx_byte_cnt + BEAT_BYTES;
      tx_rd_ptr <= tx_rd_ptr + 1;
      if (packet_len_saved - tx_byte_cnt <= BEAT_BYTES)
        tx_state <= TX_RESP;
    end else
      m_axi_wvalid <= 0;

    tx_data_stage2 <= tx_data_stage1;
    tx_data_stage1 <= ~tx_buf_sel ? buffer0[tx_rd_ptr] : buffer1[tx_rd_ptr];
  end
  TX_RESP: if (m_axi_bvalid) begin
    tx_state <= TX_IDLE;
    m_axi_wvalid <= 0;
    m_axi_wlast <= 0;
    tx_addr <= tx_addr + ((packet_len_saved + BEAT_BYTES - 1) / BEAT_BYTES) * BEAT_BYTES;
  end
endcase

endmodule
