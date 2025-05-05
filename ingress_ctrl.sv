module ingress_ctrl #(
    parameter ADDR_WIDTH = 31, //Use 2GB of DDR
    parameter DATA_WIDTH = 512,
    parameter ID_WIDTH = 4,
    parameter BUFFER_DEPTH = 2048  //in bytes
) (
    input logic clk,
    input logic rst,
    //AXI4S write transaction from MRMAC
    input logic [DATA_WIDTH-1:0] s_axis_tdata,
    input logic s_axis_tvalid,
    output logic s_axis_tready,
    input logic s_axis_tlast,
    //AXI4 write transaction to DDR
    output logic [ID_WIDTH-1:0] m_axi_awid,
    output logic [ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [7:0] m_axi_awlen,
    output logic [2:0] m_axi_awsize,
    output logic [1:0] m_axi_awburst,
    output logic m_axi_awvalid,
    input logic m_axi_awready,
    output logic [DATA_WIDTH-1:0] m_axi_wdata,
    output logic [(DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output logic m_axi_wlast,
    output logic m_axi_wvalid,
    input logic m_axi_wready,
    output logic m_axi_bready,

    //status
    output logic [31:0] pkt_cnt //# of valid packets detected
);
  localparam FEP_HEADER = 48'h1eadfeb5ac0d;  //customer header field
  localparam BEAT_BYTES = DATA_WIDTH / 8;  //# of bytes in a beat
  localparam BUFFER_WORDS = BUFFER_DEPTH / BEAT_BYTES;
  localparam IPV4_TYPE = 16'h0800;
  localparam IPV6_TYPE = 16'h86dd;
  localparam MIN_PKT_LENGTH = 63;  //byte
  localparam MAX_PKT_LENGTH = 1519;  //byte
  localparam IPV4_LENGTH_OFFSET = 18;  //Ethernet frame header + CRC
  localparam IPV6_LENGTH_OFFSET = 58;  //Ethernet frame header + CRC + Ipv6 header

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic                  last;
  } fifo_entry_t;
  fifo_entry_t fifo[0:BUFFER_WORDS-1];
  logic [$clog2(BUFFER_WORDS)-1:0] wr_ptr, rd_ptr;
  logic fifo_full, fifo_empty;
  assign fifo_full  = (wr_ptr + 1 == rd_ptr);
  assign fifo_empty = (rd_ptr == wr_ptr);
  logic [15:0] byte_cnt_next; //# of DDR bytes needed to store the current packet
  logic [15:0] byte_cnt;
  logic [15:0] pkt_length_ipv4;
  logic [15:0] pkt_length_ipv6;
  logic [15:0] pkt_length_in;
  logic [15:0] pkt_length_out;
  logic [15:0] ether_type;
  logic is_ipv4;
  logic is_ipv6;
  logic hdr_chk_pass;  //current packet is valid
  logic pkt_valid;
  logic pkt_dropping;  //current packet is invalid
  logic header_beat;
  logic [2:0] fifo_dout_valid;
  fifo_entry_t fifo_out_d0;
  fifo_entry_t fifo_out_d1;
  fifo_entry_t fifo_out_d2;
  logic [ADDR_WIDTH-1:0] ddr_wr_ptr;

  //13th and 14th bytes of the packet are the EtherType
  assign ether_type = {s_axis_tdata[13*8-1-:8], s_axis_tdata[14*8-1-:8]};
  //17th and 18th bytes of the packet are the ipv4 packet length
  assign pkt_length_ipv4 = {s_axis_tdata[17*8-1-:8], s_axis_tdata[18*8-1-:8]} + IPV4_LENGTH_OFFSET;
  //19th and 20th bytes of the packet are the ipv6 packet length
  assign pkt_length_ipv6 = {s_axis_tdata[19*8-1-:8], s_axis_tdata[20*8-1-:8]} + IPV6_LENGTH_OFFSET;
  assign is_ipv4 = ether_type == IPV4_TYPE;
  assign is_ipv6 = ether_type == IPV6_TYPE;
  assign hdr_chk_pass = (is_ipv4 && pkt_length_ipv4 > MIN_PKT_LENGTH && pkt_length_ipv4 < MAX_PKT_LENGTH) ||
                      (is_ipv6 && pkt_length_ipv6 > MIN_PKT_LENGTH && pkt_length_ipv6 < MAX_PKT_LENGTH);
  //store the total number of valid bytes in the packet
  //MRMAC doesn't include the CRC, so minus 4                      
  assign pkt_length_in = is_ipv4 ? pkt_length_ipv4 - 4 : pkt_length_ipv6 - 4;

  assign m_axi_awid = '0;
  assign m_axi_awburst = 2'b01;
  assign m_axi_awsize = $clog2(BEAT_BYTES);
  assign m_axi_bready = 1;  //don't care about the response

  // Stream input logic. This supports back to back packets
  assign s_axis_tready = ~fifo_full; //packet is lost if FIFO is full as MRMAC will not stop sending packets

  always_ff @(posedge clk) begin
    if (rst) begin
      wr_ptr <= 0;
      pkt_valid <= '0;
      pkt_dropping <= '0;
      pkt_cnt <= '0;
    end else begin
      if (s_axis_tvalid && !fifo_full) begin
        if (!pkt_valid && !pkt_dropping) begin //neither of these flags is set means this is the first beat of a new packet
          if (hdr_chk_pass) begin
            pkt_valid <= '1;
            pkt_cnt <= pkt_cnt + 1;
            //replace MAC address with TMRed packet length and FEP header
            fifo[wr_ptr].data <= {
              s_axis_tdata[DATA_WIDTH-1:96], FEP_HEADER, pkt_length_in, pkt_length_in, pkt_length_in
            };
            fifo[wr_ptr].last <= s_axis_tlast;
            wr_ptr <= wr_ptr + 1;
          end else begin
            pkt_dropping <= 1;
          end
        end else if (pkt_valid) begin //otherwise this is a continuation of the current packet and if the packet is already valid, store it
          fifo[wr_ptr].data <= s_axis_tdata;
          fifo[wr_ptr].last <= s_axis_tlast;
          wr_ptr <= wr_ptr + 1;
        end  //otherwise do nothing for the packet that is being dropped

        if (s_axis_tlast) begin  //clear the flags when the last beat of the packet is received
          pkt_valid <= '0;
          pkt_dropping <= 0;
        end
      end
    end
  end

  // Replace this with AMD XPM FIFO
  // FIFO read latency = 3
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

  // Burst write output logic
  // can do back to back burst writes
  // address beat and first data beat are at the same time
  // assume writes are always successful
  assign pkt_length_out = fifo_out_d2.data[15:0];
  assign byte_cnt_next = ((pkt_length_out + BEAT_BYTES - 1) / BEAT_BYTES) * BEAT_BYTES;
  assign m_axi_wstrb = '1; //always write the entire 512 bit word into DDR as if all bytes are valid
  
  always_ff @(posedge clk)
    if (rst) begin
      rd_ptr <= '0;
      byte_cnt <= '0;
      m_axi_awvalid <= '0;
      m_axi_awaddr <= '0;
      m_axi_wvalid <= '0;
      m_axi_wlast <= '0;
      header_beat <= '1;
      fifo_dout_valid <= '0;
      ddr_wr_ptr <= '0;
    end else begin
      if (m_axi_wready) begin

        if (~fifo_empty) rd_ptr <= rd_ptr + 1;

        fifo_dout_valid[2:0] <= {fifo_dout_valid[1:0], ~fifo_empty};  //match the FIFO read latency
        //put FIFO data on the bus when it is valid
        m_axi_wvalid <= fifo_dout_valid[2];

        if (fifo_dout_valid[2]) begin
          header_beat <= fifo_out_d2.last;
          m_axi_wlast <= fifo_out_d2.last;
          
          if (fifo_out_d2.last) //at the end of the burst, set the next DDR write address
            if (header_beat)
              ddr_wr_ptr <= ddr_wr_ptr + byte_cnt_next;
            else
              ddr_wr_ptr <= ddr_wr_ptr + byte_cnt;

          //if writing header
          if (header_beat) begin
            m_axi_awaddr <= ddr_wr_ptr;
            m_axi_awvalid <= 1;
            //Always write the entire 512 bit word into DDR as if all bytes are valid
            //store the number of bytes to be taken by the current packet
            byte_cnt <= byte_cnt_next;
          end else begin  //writing non-header
            m_axi_awvalid <= '0;
          end
        end else  //FIFO dout is no longer valid
        begin
          m_axi_wlast   <= '0;
          m_axi_awvalid <= '0;
        end
      end  //if (rst)

      if (fifo_dout_valid[2] && m_axi_wready) begin
        m_axi_wdata <= fifo_out_d2.data;
        m_axi_awlen <= (pkt_length_out + BEAT_BYTES - 1) / BEAT_BYTES - 1;
      end
    end

//Use DDR as a FIFO
  
  

endmodule
