module ingress_ctrl #(
    parameter ADDR_WIDTH = 31, //Use 2GB of DDR
    parameter DATA_WIDTH = 512,
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
    input logic m_axi_bvalid,
    //DDR reads
    output logic [ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0] m_axi_arlen,
    output logic [2:0] m_axi_arsize,
    output logic [1:0] m_axi_arburst,
    output logic m_axi_arvalid,
    input logic m_axi_arready,
    input logic [DATA_WIDTH-1:0] m_axi_rdata,
    input logic m_axi_rlast,
    input logic m_axi_rvalid,
    output logic m_axi_rready,
    //AXI4S write transaction to AMPER
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic m_axis_tlast,
    output logic [(DATA_WIDTH/8)-1:0] m_axis_tkeep,
    //CSR
    input logic ddr_rd_en, //1 to enable DDR read
    output logic [31:0] pkt_cnt //# of valid packets detected
);
localparam FEP_HEADER = 48'h1eadfeb5ac0d;  //customer header field
localparam BEAT_BYTES = DATA_WIDTH / 8;  //# of bytes in a beat
localparam BUFFER_WORDS = BUFFER_DEPTH / BEAT_BYTES;
localparam IPV4_TYPE = 16'h0800;
localparam IPV6_TYPE = 16'h86dd;
localparam MIN_PKT_LENGTH = 63;  //byte
localparam MAX_PKT_LENGTH = 1519;  //byte
localparam MAX_BEAT_CNT = (MAX_PKT_LENGTH-1-4+BEAT_BYTES-1)/BEAT_BYTES;
localparam IPV4_LENGTH_OFFSET = 18;  //Ethernet frame header + CRC
localparam IPV6_LENGTH_OFFSET = 58;  //Ethernet frame header + CRC + Ipv6 header

typedef enum logic [2:0] {
  DDR_WR_IDLE,
  DDR_WR_ADDR, //address cycle
  DDR_WR_HEADER, //first data cycle
  DDR_WR_WAIT, //wait FIFO 
  DDR_WR_BURST, //burst data
  DDR_WR_RESP  //response cycle
} DDR_WR_ST_T;

typedef struct packed {
  logic [DATA_WIDTH-1:0] data;
  logic                  last;
} fifo_entry_t;
fifo_entry_t fifo[0:BUFFER_WORDS-1];
logic [$clog2(BUFFER_WORDS)-1:0] wr_ptr, rd_ptr;
logic fifo_full, fifo_empty;
assign fifo_full  = (wr_ptr + 1 == rd_ptr);
assign fifo_empty = (rd_ptr == wr_ptr);
fifo_entry_t fifo_out_d0;
fifo_entry_t fifo_out_d1;
fifo_entry_t fifo_out_d2;

DDR_WR_ST_T ddr_wr_st;
DDR_WR_ST_T ddr_wr_next_st;
logic [15:0] byte_cnt_next; //# of DDR bytes needed to store the current packet
logic [15:0] byte_cnt;
logic [15:0] pkt_length_ipv4;
logic [15:0] pkt_length_ipv6;
logic [15:0] pkt_length;
logic [15:0] pkt_length_fifo; //packet length recovered from the output of the FIFO
logic [15:0] pkt_length_ddr[3]; //packet length recovered from the output of the DDR
logic [15:0] pkt_length_voted;
logic fep_match;
logic [15:0] ether_type;
logic is_ipv4;
logic is_ipv6;
logic hdr_chk_pass;  //current packet is valid
logic pkt_valid;
logic pkt_dropping;  //current packet is invalid
logic header_beat;
logic fifo_rd_req;
logic [2:0] fifo_rd_req_d;
logic fifo_rd_en;
logic [ADDR_WIDTH-1:0] ddr_wr_ptr;
logic [ADDR_WIDTH-1:0] ddr_rd_ptr;
logic ddr_empty;
logic ddr_full;
logic find_header;
logic [$clog2(MAX_BEAT_CNT)-1:0] wr_beat_cnt;
logic [$clog2(MAX_BEAT_CNT)-1:0] wr_beat_left;
logic [$clog2(MAX_BEAT_CNT)-1:0] rd_beat_cnt;
logic [$clog2(MAX_BEAT_CNT)-1:0] rd_beat_left;
logic [$clog2(BEAT_BYTES)-1:0] byte_in_last_beat;
logic [BEAT_BYTES-1:0] byte_valid;
logic [BEAT_BYTES-1:0] byte_valid_save;

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
assign pkt_length = is_ipv4 ? pkt_length_ipv4 - 4 : pkt_length_ipv6 - 4;

assign m_axi_awburst = 2'b01;
assign m_axi_awsize = $clog2(BEAT_BYTES);
assign m_axi_bready = 1;  //don't care about the response

//------------------------------------------------------------------------------
// Stream input logic. This supports back to back packets
//------------------------------------------------------------------------------
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
            s_axis_tdata[DATA_WIDTH-1:96], FEP_HEADER, pkt_length, pkt_length, pkt_length
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

// Replace these code with a AMD XPM FIFO
// FIFO read latency = 3
always_ff @(posedge clk) begin
  if (rst) begin
    fifo_out_d0 <= '0;
    fifo_out_d1 <= '0;
    fifo_out_d2 <= '0;
    rd_ptr <= '0;
  end else begin
    if (fifo_rd_en)
      fifo_out_d0 <= fifo[rd_ptr];
    if (ddr_wr_st==DDR_WR_BURST && m_axi_wready || ddr_wr_st!=DDR_WR_BURST)
    begin
    fifo_out_d1 <= fifo_out_d0;
    fifo_out_d2 <= fifo_out_d1;
    end
    if (fifo_rd_en)
      rd_ptr <= rd_ptr+1; 
  end
end

//------------------------------------------------------------------------------
// DDR Burst write output logic
//------------------------------------------------------------------------------
// can not do back burst writes
// Separate address cycle and data cycle
// Expect write response
assign pkt_length_fifo = fifo_out_d2.data[15:0];
assign wr_beat_cnt = ((pkt_length_fifo + BEAT_BYTES - 1) / BEAT_BYTES);
assign byte_cnt_next = wr_beat_cnt * BEAT_BYTES;
assign m_axi_wstrb = '1; //always write the entire 512 bit word into DDR as if all bytes are valid
assign m_axi_awlen = wr_beat_cnt - 1; //burst length - 1
assign fifo_rd_en = ddr_wr_st == DDR_WR_BURST ? m_axi_wready && fifo_rd_req : fifo_rd_req;

always_comb begin
  ddr_wr_next_st = ddr_wr_st;
  case(ddr_wr_st)
    DDR_WR_IDLE: 
    if (~fifo_empty)
      ddr_wr_next_st = DDR_WR_ADDR;
    DDR_WR_ADDR:
    if (m_axi_awvalid && m_axi_awready)
      ddr_wr_next_st = DDR_WR_HEADER;
    DDR_WR_HEADER:
      if (m_axi_wready)
        if (wr_beat_cnt<2)
          ddr_wr_next_st = DDR_WR_RESP;
        else 
          ddr_wr_next_st = DDR_WR_WAIT;        
    DDR_WR_WAIT:
      if (fifo_rd_req_d[2])
        ddr_wr_next_st = DDR_WR_BURST;
    DDR_WR_BURST:    
    if (m_axi_wvalid && m_axi_wready && m_axi_wlast)     
      ddr_wr_next_st = DDR_WR_RESP;
    DDR_WR_RESP:
    if (m_axi_bvalid)
      ddr_wr_next_st <= DDR_WR_IDLE;
    default:
      ddr_wr_next_st <= DDR_WR_IDLE;
  endcase
end

always_ff @(posedge clk) begin
  if (rst) begin
    ddr_wr_st <= DDR_WR_IDLE;
    fifo_rd_req <= '0;
    m_axi_awvalid <= '0;
    m_axi_awaddr <= '0;
    m_axi_wvalid <= '0;
    wr_beat_left <= '0;
  end else begin
    ddr_wr_st <= ddr_wr_next_st;
    case(ddr_wr_st)
      DDR_WR_IDLE:
        if (~fifo_empty)
          fifo_rd_req <= 1; //single read
      DDR_WR_ADDR: begin
        fifo_rd_req <= 0; //pause read to process data
        fifo_rd_req_d <= {fifo_rd_req_d[1:0], fifo_rd_req}; //match the FIFO read latency
        if (fifo_rd_req_d[2]) //when data is valid, output to the bus
          begin
          m_axi_awvalid <= 1;
          wr_beat_left <= wr_beat_cnt;
          end
        if (m_axi_awvalid && m_axi_awready) begin
          m_axi_awvalid <= 0; //address cycle ends
          m_axi_wvalid <= 1;
          m_axi_awaddr <= m_axi_awaddr + wr_beat_cnt * BEAT_BYTES; //prepare for next packet
          end
        end
      DDR_WR_HEADER: begin
        fifo_rd_req_d <= {fifo_rd_req_d[1:0], fifo_rd_req}; //match the FIFO read latency
        if (m_axi_wready) begin
          m_axi_wvalid <= 0;
          wr_beat_left <= wr_beat_left-1;
          if (wr_beat_left>1 && ~fifo_empty)
            fifo_rd_req <= 1;            
          end
        end  
      DDR_WR_WAIT: begin
        fifo_rd_req_d <= {fifo_rd_req_d[1:0], fifo_rd_req};
        if (wr_beat_left>1)
          wr_beat_left <= wr_beat_left - 1;
        else
          fifo_rd_req <= 0;
        if (fifo_rd_req_d[2])
          m_axi_wvalid <= 1;
        end  
      DDR_WR_BURST: begin//payload beat
        //FIFO should not become empty
        if (m_axi_wready) begin
          fifo_rd_req_d <= {fifo_rd_req_d[1:0], fifo_rd_req};
          if(wr_beat_left>1) begin
            wr_beat_left <= wr_beat_left - 1;
            fifo_rd_req <= 1;
          end else
          fifo_rd_req <= 0;
        end
        if (m_axi_wready && m_axi_wlast) //wvalid stay high during burst.
          m_axi_wvalid <= 0;
      end       
    endcase
  end
  if (ddr_wr_st==DDR_WR_BURST && m_axi_wready || ddr_wr_st!=DDR_WR_BURST) begin
  m_axi_wdata <= fifo_out_d2.data;
  m_axi_wlast <= fifo_out_d2.last;
  end
end
/*
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
    if (m_axi_wready && m_axi_awready) begin
      if (fifo_rd_en) 
        rd_ptr <= rd_ptr + 1;
      
      fifo_dout_valid[2:0] <= {fifo_dout_valid[1:0], fifo_rd_en};  //match the FIFO read latency
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
      m_axi_awlen <= (pkt_length_fifo + BEAT_BYTES - 1) / BEAT_BYTES - 1;
    end
  end
  */

//DDR single read logic
assign ddr_full = ddr_wr_ptr + 1 == ddr_rd_ptr;
assign ddr_empty = ddr_wr_ptr == ddr_rd_ptr;
assign m_axi_arlen    = 8'd0; // Single transfer
assign m_axi_arsize   = $clog2(DATA_WIDTH / 8);
assign m_axi_arburst  = 2'b01; // INCR burst
assign m_axi_arvalid  = ddr_rd_en && !ddr_empty;
assign m_axi_araddr   = ddr_rd_ptr;
//increment address when the read transaction is accepted by DDRMC
always_ff @(posedge clk)
  if (rst)
    ddr_rd_ptr <= '0;
  else
    if (m_axi_arready)
      ddr_rd_ptr <= ddr_rd_ptr + BEAT_BYTES;

//accept DDR read data when the AMPER is ready to take the data
assign m_axi_rready = m_axis_tready;

//Output to AMPER via AXIS
assign pkt_length_ddr[0] = m_axi_rdata[15:0];
assign pkt_length_ddr[1] = m_axi_rdata[31:16];
assign pkt_length_ddr[2] = m_axi_rdata[47:32];
assign pkt_length_voted = (pkt_length_ddr[0] & pkt_length_ddr[1]) |
                          (pkt_length_ddr[1] & pkt_length_ddr[2]) |
                          (pkt_length_ddr[0] & pkt_length_ddr[2]);
assign rd_beat_cnt = (pkt_length_voted + BEAT_BYTES - 1) / BEAT_BYTES;
assign byte_in_last_beat = pkt_length_voted % BEAT_BYTES;
assign byte_valid = {BEAT_BYTES{1'b1}} >> (BEAT_BYTES - byte_in_last_beat);
assign fep_match =  FEP_HEADER == m_axi_rdata[95:48];

assign m_axis_tvalid = m_axi_rvalid;
assign m_axis_tlast = find_header ? rd_beat_cnt<2 : rd_beat_left == 0;
assign m_axis_tkeep = find_header && rd_beat_left == 0 ? byte_valid_save : byte_valid;

//search for the header beat
always_ff @(posedge clk)
  if (rst) begin
    find_header <= '1;
    rd_beat_left <= '0;
    byte_valid_save <= '1;
    end
  else
    if (m_axi_rvalid && m_axis_tready)
      if (find_header)
        begin
        rd_beat_left <= rd_beat_cnt-1;
        byte_valid_save <= byte_valid;
        if (fep_match)
          find_header <= rd_beat_cnt < 2; //keep looking for the next header if the current packet has 1 beat
        end
      else
        begin
        find_header <= rd_beat_left == 0;
        rd_beat_left <= rd_beat_left - 1;
        end

endmodule
