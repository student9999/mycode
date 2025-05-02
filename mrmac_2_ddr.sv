module mrmac_2_ddr #(
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

localparam BEAT_BYTES = DATA_WIDTH / 8; //# of bytes in a beat
localparam BUFFER_WORDS = BUFFER_DEPTH / BEAT_BYTES;
localparam SIZE_CODE = $clog2(BEAT_BYTES);

typedef struct packed {
  logic [DATA_WIDTH-1:0] data;
  logic                  last;
} fifo_entry_t;

fifo_entry_t fifo [0:BUFFER_WORDS-1];
logic [$clog2(BUFFER_WORDS)-1:0] wr_ptr, rd_ptr;
logic [15:0] byte_cnt;
logic [ADDR_WIDTH-1:0] addr;
logic [15:0] total_length;
logic fifo_full, fifo_empty;
logic pkt_valid, pkt_dropping;
logic [2:0] wvalid_hold;
logic read_header;
fifo_entry_t fifo_out_d0;
fifo_entry_t fifo_out_d1;
fifo_entry_t fifo_out_d2;

assign total_length = {s_axis_tdata[135:128], s_axis_tdata[143:136]};
assign fifo_full  = (wr_ptr + 1 == rd_ptr);
assign fifo_empty = (rd_ptr == wr_ptr);
assign m_axi_awid = '0;
assign m_axi_awburst = 2'b01;
assign m_axi_awsize = SIZE_CODE;
assign m_axi_bready = 1;

// Stream input logic
always_ff @(posedge clk) begin
  if (rst) begin
    wr_ptr <= 0;
    s_axis_tready <= 1;
    pkt_valid <= 0;
    pkt_dropping <= 0;
  end else begin
    if (s_axis_tvalid && !fifo_full) begin
      if (!pkt_valid && !pkt_dropping) begin
        if (total_length >= 64 && total_length <= 1500) begin
          pkt_valid <= 1;
          fifo[wr_ptr].data <= s_axis_tdata;
          fifo[wr_ptr].last <= s_axis_tlast;
          wr_ptr <= wr_ptr + 1;
        end else begin
          pkt_dropping <= 1;
        end
      end else if (pkt_valid) begin
        fifo[wr_ptr].data <= s_axis_tdata;
        fifo[wr_ptr].last <= s_axis_tlast;
        wr_ptr <= wr_ptr + 1;
      end

      if (s_axis_tlast) begin
        pkt_valid <= 0;
        pkt_dropping <= 0;
      end
    end
  end
end

// FIFO read latency 3
always_ff @(posedge clk) begin
  if (rst) begin
    fifo_out_d0 <= '0;
    fifo_out_d1 <= '0;
    fifo_out_d2 <= '0;
  end else begin
    if (m_axi_wready) begin
      fifo_out_d0 <= fifo[rd_ptr];
      fifo_out_d1 <= fifo_out_d0;
      fifo_out_d2 <= fifo_out_d1;  
    end
  end
end

logic [15:0] packet_lenth;
logic header_beat;
assign packet_lenth = {fifo_out_d2.data[135:128], fifo_out_d2.data[143:136]};

// Write output logic
always_ff @(posedge clk) begin
  if (rst) begin
    rd_ptr <= 0;
    byte_cnt <= 0;
    addr <= 0;
    m_axi_awvalid <= 0;
    m_axi_awaddr <= '0;
    m_axi_awlen <= 0;
    m_axi_wvalid <= '0;
    m_axi_wlast <= 0;
    m_axi_wstrb <= '1;
    header_beat <= '1;
    wvalid_hold <= '0;
  end else begin
    if (m_axi_wready) begin
      wvalid_hold[2:0] <= {wvalid_hold[1:0], ~fifo_empty};
      if (~fifo_empty)
        rd_ptr <= rd_ptr + 1;
      m_axi_wvalid <= wvalid_hold[2];
      if (wvalid_hold[2]) begin
        header_beat <= fifo_out_d2.last;
        m_axi_wlast <= fifo_out_d2.last;
      end else
        m_axi_wlast <= '0;
      if (wvalid_hold[2] && header_beat) begin
        m_axi_awlen <= (packet_lenth + BEAT_BYTES - 1) / BEAT_BYTES - 1;
        m_axi_awaddr <= m_axi_awaddr + byte_cnt;
        byte_cnt <= ((packet_lenth + BEAT_BYTES - 1) / BEAT_BYTES) * BEAT_BYTES;
        end
      end 
    end //if (rst)

  if (wvalid_hold[2] && m_axi_wready)
    m_axi_wdata <= fifo_out_d2.data;
     
  end

endmodule
