`timescale 1ns / 1ps
module tb;

  parameter ADDR_WIDTH = 31;
  parameter DATA_WIDTH = 512;
  parameter ID_WIDTH = 4;
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
  logic m_axi_bready;

  bit start_pushback = 0;
  bit [15:0] tx_pkt_cnt = 0;
  bit [15:0] rx_pkt_cnt = 0;
  bit [15:0] dut_pkt_cnt;

  ingress_ctrl #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .ID_WIDTH  (ID_WIDTH)
  ) dut (
      .pkt_cnt(dut_pkt_cnt),
      .*
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task reset();
    rst <= 1;
    repeat (5) @(posedge clk);
    rst <= 0;
  endtask

  task send_pkt(input int pkt_type, input int pkt_len);
    automatic int beats = (pkt_len + BEAT_BYTES - 1) / BEAT_BYTES;
    s_axis_tvalid <= 1;
    s_axis_tlast  <= 0;

    for (int i = 0; i < beats; i++) begin
      s_axis_tdata <= $urandom;
      if (i == 0) begin
        // Set total length field at byte 13 and 14 (big endian)
        s_axis_tdata[14*8-1-:16] <= {pkt_type[7:0], pkt_type[15:8]};
        // Set total length field at byte 17 and 18 (big endian)
        s_axis_tdata[18*8-1-:16] <= {pkt_len[7:0], pkt_len[15:8]};
        // Set total length field at byte 19 and 20 (big endian)
        s_axis_tdata[20*8-1-:16] <= {pkt_len[7:0], pkt_len[15:8]};
        // test pattern
        s_axis_tdata[15:0] <= tx_pkt_cnt;
      end
      if (i == beats - 1) begin
        s_axis_tlast <= 1;
        tx_pkt_cnt   <= tx_pkt_cnt + 1;
      end
      @(posedge clk iff s_axis_tready);
    end

    s_axis_tvalid <= 0;
    s_axis_tlast  <= 0;
  endtask

  initial begin
    m_axi_awready <= 1;
    m_axi_wready  <= 1;

    reset();

    @(posedge clk);
    send_pkt(16'h0800, 400);
    repeat (20) @(posedge clk);
    send_pkt(16'h86dd, 800);
    repeat (100) @(posedge clk);
    //back to back packets
    send_pkt(16'h86dd, 6);
    send_pkt(16'h0800, 46);
    send_pkt(16'h86dd, 6);
    send_pkt(16'h0800, 46);

    //single beat packet
    repeat (20) @(posedge clk);
    send_pkt(16'h0800, 61);
    repeat (20) @(posedge clk);

    //back to back packets while DDR is pushing back
    start_pushback = 1;
    repeat (50) begin
      send_pkt(16'h86dd, 6);
      send_pkt(16'h0800, 46);
    end

    wait (dut.fifo_empty);
    repeat (10) @(posedge clk);
    if (tx_pkt_cnt != rx_pkt_cnt) $display("Error: Packet counts do not match at time %0t", $time);
    #1000;
    $finish;
  end

  initial begin
    m_axi_wready <= 1;
    @(posedge m_axi_wvalid);
    repeat (100) begin
      @(posedge clk);
      m_axi_wready <= ~m_axi_wready;
    end

    @(posedge clk);
    m_axi_wready <= 1;

    @(start_pushback);
    repeat (100) begin
      @(posedge clk);
      m_axi_wready <= ~m_axi_wready;
    end
  end

  always_ff @(posedge clk)
    if (m_axi_wvalid && m_axi_wready && m_axi_wlast)
      rx_pkt_cnt <= rx_pkt_cnt + 1;

  initial begin
    $fsdbDumpfile("waves.fsdb");
    $fsdbDumpvars(0, tb);
    // Optional: $fsdbDumpMDA(); // For dumping memory arrays
  end

endmodule
