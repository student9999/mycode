`timescale 1ns / 1ps

module tb_axis_2_axi;

  parameter ADDR_WIDTH = 32;
  parameter DATA_WIDTH = 512;
  parameter ID_WIDTH   = 4;
  parameter BEAT_BYTES = DATA_WIDTH / 8;

  logic clk;
  logic rst;
  logic [DATA_WIDTH-1:0] s_axis_tdata;
  logic s_axis_tvalid;
  logic s_axis_tready;
  logic s_axis_tlast;
  logic [ID_WIDTH-1:0] m_axi_awid;
  logic [ADDR_WIDTH-1:0] m_axi_awaddr;
  logic [7:0] m_axi_awlen;
  logic [2:0] m_axi_awsize;
  logic [1:0] m_axi_awburst;
  logic m_axi_awvalid;
  logic m_axi_awready;
  logic [DATA_WIDTH-1:0] m_axi_wdata;
  logic [(DATA_WIDTH/8)-1:0] m_axi_wstrb;
  logic m_axi_wlast;
  logic m_axi_wvalid;
  logic m_axi_wready;
  logic [ID_WIDTH-1:0] m_axi_bid;
  logic [1:0] m_axi_bresp;
  logic m_axi_bvalid=0;
  logic m_axi_bready;

  axis_2_axi #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH)
  ) dut (
    .*);

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task reset();
    rst <= 1;
    repeat (5) @(posedge clk);
    rst <= 0;
  endtask

  task send_ipv4_packet(input int pkt_len);
    automatic int beats = (pkt_len + BEAT_BYTES - 1) / BEAT_BYTES;
    s_axis_tvalid <= 1;
    s_axis_tlast <= 0;

    for (int i = 0; i < beats; i++) begin
      s_axis_tdata <= $urandom;
      if (i == 0) begin
        // Set total length field at byte 16 and 17 (big endian)
        s_axis_tdata[143:128] <= {pkt_len[7:0], pkt_len[15:8]};
      end
      if (i == beats-1) s_axis_tlast <= 1;
      wait (s_axis_tready);
      @(posedge clk);
    end

    s_axis_tvalid <= 0;
    s_axis_tlast <= 0;
  endtask

  initial begin
    m_axi_awready <= 1;
    m_axi_wready <= 1;

    reset();

    @(posedge clk);
    send_ipv4_packet(400);
    repeat (20) @(posedge clk);
    send_ipv4_packet(800);
    repeat (100) @(posedge clk);

    $finish;
  end

  always_ff @(posedge clk) begin
    if (m_axi_wvalid && m_axi_wready && m_axi_wlast) begin
      m_axi_bvalid <= 1;
    end else if (m_axi_bvalid && m_axi_bready) begin
      m_axi_bvalid <= 0;
    end
  end

initial begin
    $fsdbDumpfile("waves.fsdb");
    $fsdbDumpvars(0, axis_2_axi);
    // Optional: $fsdbDumpMDA(); // For dumping memory arrays
end

endmodule
