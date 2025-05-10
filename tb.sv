`timescale 1ns / 1ps
module tb;

  parameter ADDR_WIDTH = 31;
  parameter DATA_WIDTH = 512;
  parameter ID_WIDTH = 4;
  parameter BEAT_BYTES = DATA_WIDTH / 8;
  localparam IPV4_TYPE = 16'h0800;
  localparam IPV6_TYPE = 16'h86dd;

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
  logic m_axi_awready=0;
  logic [DATA_WIDTH-1:0] m_axi_wdata;
  logic [(DATA_WIDTH/8)-1:0] m_axi_wstrb;
  logic m_axi_wlast;
  logic m_axi_wvalid;
  logic m_axi_wready;
  logic [ID_WIDTH-1:0] m_axi_bid;
  logic [1:0] m_axi_bresp;
  logic m_axi_bready;
  logic m_axi_bvalid=1;

  logic [ADDR_WIDTH-1:0] m_axi_araddr;
  logic [7:0] m_axi_arlen;
  logic [2:0] m_axi_arsize;
  logic [1:0] m_axi_arburst;
  logic m_axi_arvalid;
  logic m_axi_arready=0;
  logic [DATA_WIDTH-1:0] m_axi_rdata;
  logic m_axi_rlast;
  logic m_axi_rvalid;
  logic m_axi_rready;
;
  logic [DATA_WIDTH-1:0] m_axis_tdata;
  logic m_axis_tvalid;
  logic m_axis_tready;
  logic m_axis_tlast;
  logic [(DATA_WIDTH/8)-1:0] m_axis_tkeep;
  logic ddr_rd_en=0; //1 to enable DDR rea
  logic [31:0] pkt_cnt; //# of valid packets detecte
  bit [11:0] beat_cnt=0; //# of valid packets detecte

  bit start_pushback = 0;
  bit [15:0] tx_pkt_cnt = 0;
  bit [15:0] rx_pkt_cnt = 0;
  bit [15:0] dut_pkt_cnt;
  bit [15:0] s_axis_tdata_monitor;
  assign s_axis_tdata_monitor = s_axis_tdata[16*8-1-:16];
  bit [15:0] m_axi_wdata_monitor;
  assign m_axi_wdata_monitor = m_axi_wdata[16*8-1-:16];
  bit force_awready_low=0;
  bit force_awready_high=0;
  bit force_wready_low=0;
  bit force_wready_high=0;

  ingress_ctrl #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH))
  dut (
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

  task send_pkt(input int pkt_type, input int pkt_len); //pkt_len is the total bytes MRMAC outputs = header+payload (without CRC)
    automatic int beats = (pkt_len + BEAT_BYTES - 1) / BEAT_BYTES;
    automatic int length_field = pkt_type == IPV4_TYPE ? pkt_len - 14 : 
                 pkt_type == IPV6_TYPE ? pkt_len - 54 :
                 pkt_len;
    s_axis_tvalid <= 1;
    s_axis_tlast  <= 0;
    for (int i = 0; i < beats; i++) begin
      s_axis_tdata <= $urandom;
      beat_cnt <= beat_cnt + 1;
      s_axis_tdata[16*8-1-:16] <= {tx_pkt_cnt[3:0], beat_cnt[11:0]};
      if (i == 0) begin
        // Set total length field at byte 13 and 14 (big endian)
        s_axis_tdata[14*8-1-:16] <= {pkt_type[7:0], pkt_type[15:8]};
        // Set total length field at byte 17 and 18 (big endian)
        s_axis_tdata[18*8-1-:16] <= {length_field[7:0], length_field[15:8]};
        // Set total length field at byte 19 and 20 (big endian)
        s_axis_tdata[20*8-1-:16] <= {length_field[7:0], length_field[15:8]};
        // test pattern on byte 15 and 16
      end
      if (i == beats - 1) begin
        s_axis_tlast <= 1;
        tx_pkt_cnt   <= tx_pkt_cnt + 1;
        beat_cnt <= 0;
      end
      @(posedge clk iff s_axis_tready);
    end

    s_axis_tvalid <= 0;
    s_axis_tlast  <= 0;
  endtask

  initial begin

    reset();
    @(posedge clk);
    //back to back packets
    send_pkt(16'h86dd, 60);
    send_pkt(16'h0800, 60);
    send_pkt(16'h86dd, 60);
    send_pkt(16'h0800, 60);
    #500;

    @(posedge clk);
    send_pkt(16'h0800, 400);
    repeat (20) @(posedge clk);
    send_pkt(16'h86dd, 800);
    repeat (100) @(posedge clk);
    //back to back packets
    send_pkt(16'h86dd, 64);
    send_pkt(16'h0800, 64);
    send_pkt(16'h86dd, 64);
    send_pkt(16'h0800, 64);

    //single beat packet
    repeat (20) @(posedge clk);
    send_pkt(16'h0800, 64);
    repeat (20) @(posedge clk);

    //back to back packets while DDR is pushing back
    start_pushback = 1;
    repeat (50) begin
      send_pkt(16'h86dd, 64);
      send_pkt(16'h0800, 64);
    end

    //Just a normal packet
    repeat (40) @(posedge clk);
    send_pkt(16'h0800, 1200);
    
    //max size packet
    repeat (40) @(posedge clk);
    send_pkt(16'h0800, 1514);

    repeat (20) @(posedge clk);
    send_pkt(16'h86dd, 100);

    @ (posedge m_axi_awvalid);
    @(posedge clk);
    force_awready_high = 1;
    //back to back packets
    send_pkt(16'h86dd, 600);
    send_pkt(16'h86dd, 300);
    send_pkt(16'h86dd, 64);
    send_pkt(16'h0800, 64);
    send_pkt(16'h86dd, 64);
    send_pkt(16'h0800, 64);

    wait (dut.fifo_empty);
    repeat (10) @(posedge clk);
    if (tx_pkt_cnt != rx_pkt_cnt) $display("Error: Packet counts do not match at time %0t", $time);
    #1000;
    $finish;
  end

  initial begin
    m_axi_wready <= 0;
    repeat (100) begin
      @(posedge clk iff m_axi_wvalid);
      @(posedge clk);
      m_axi_wready <= 1;
      @(posedge clk);
      m_axi_wready <= 0;
    end

    @(posedge clk);
    m_axi_wready <= 1;

    @(start_pushback);
    repeat (100) begin
      @(posedge clk);
      m_axi_wready <= ~m_axi_wready;
    end
  end

always_ff @ (posedge clk) begin
  if (m_axi_awvalid)
    m_axi_awready <= ~m_axi_awready;
  if (force_awready_high)
    m_axi_awready <= 1;
  end


  always_ff @(posedge clk)
    if (m_axi_wvalid && m_axi_wready && m_axi_wlast)
      rx_pkt_cnt <= rx_pkt_cnt + 1;

  initial begin
    #2ms;
    $error("Run time passed 2ms!");
    $finish();
  end    

  initial begin
    $fsdbDumpfile("waves.fsdb");
    $fsdbDumpvars(0, tb);
    // Optional: $fsdbDumpMDA(); // For dumping memory arrays
  end

endmodule
