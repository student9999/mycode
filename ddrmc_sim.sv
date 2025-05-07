module ddrmc_sim #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 512,
    parameter ID_WIDTH   = 4,
    parameter STRB_WIDTH = DATA_WIDTH / 8,
    parameter MEM_SIZE   = 65536  // in bytes
)(
    input  wire                     ACLK,
    input  wire                     ARESET,

    // Write address channel
    input  wire [ID_WIDTH-1:0]      AWID,
    input  wire [ADDR_WIDTH-1:0]    AWADDR,
    input  wire [7:0]               AWLEN,
    input  wire [2:0]               AWSIZE,
    input  wire [1:0]               AWBURST,
    input  wire                     AWVALID,
    output wire                     AWREADY,

    // Write data channel
    input  wire [DATA_WIDTH-1:0]    WDATA,
    input  wire [STRB_WIDTH-1:0]    WSTRB,
    input  wire                     WLAST,
    input  wire                     WVALID,
    output wire                     WREADY,

    // Write response channel
    output reg  [ID_WIDTH-1:0]      BID,
    output reg  [1:0]               BRESP,
    output reg                      BVALID,
    input  wire                     BREADY,

    // Read address channel
    input  wire [ID_WIDTH-1:0]      ARID,
    input  wire [ADDR_WIDTH-1:0]    ARADDR,
    input  wire [7:0]               ARLEN,
    input  wire [2:0]               ARSIZE,
    input  wire [1:0]               ARBURST,
    input  wire                     ARVALID,
    output wire                     ARREADY,

    // Read data channel
    output reg  [ID_WIDTH-1:0]      RID,
    output reg  [DATA_WIDTH-1:0]    RDATA,
    output reg  [1:0]               RRESP,
    output reg                      RLAST,
    output reg                      RVALID,
    input  wire                     RREADY
);

    localparam MEM_DEPTH = MEM_SIZE / (DATA_WIDTH / 8);
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // ----------------------------------
    // Write Address Latching
    // ----------------------------------
    reg aw_valid_reg;
    reg [ADDR_WIDTH-1:0] aw_addr_reg;
    reg [ID_WIDTH-1:0]   aw_id_reg;
    reg [7:0]            aw_len_reg;
    reg [2:0]            aw_size_reg;
    reg wr_active;
    reg [ADDR_WIDTH-1:0] wr_addr;
    reg [7:0]            wr_cnt;
    reg [ID_WIDTH-1:0]   wr_id;

    assign AWREADY = ~aw_valid_reg;

    always @(posedge ACLK) begin
        if (ARESET) begin
            aw_valid_reg <= 1;
        end else if (AWVALID && AWREADY) begin
            aw_valid_reg <= 1;
            aw_addr_reg  <= AWADDR;
            aw_id_reg    <= AWID;
            aw_len_reg   <= AWLEN;
            aw_size_reg  <= AWSIZE;
        end else if (aw_valid_reg && WVALID && WREADY && (WLAST || wr_cnt == aw_len_reg)) begin
            aw_valid_reg <= 0;
        end
    end

    // ----------------------------------
    // Write Data Handling
    // ----------------------------------


    assign WREADY = aw_valid_reg;

    always @(posedge ACLK) begin
        if (ARESET) begin
            wr_active <= 0;
            BVALID    <= 0;
        end else begin
            if (aw_valid_reg && WVALID && WREADY) begin
                // Accept first data beat
                wr_active <= 1;
                wr_addr   <= aw_addr_reg;
                wr_cnt    <= 0;
                wr_id     <= aw_id_reg;
            end

            if (wr_active && WVALID && WREADY) begin
                integer i;
                for (i = 0; i < STRB_WIDTH; i++) begin
                    if (WSTRB[i]) begin
                        mem[wr_addr[ADDR_WIDTH-1:6]][8*i +: 8] <= WDATA[8*i +: 8];
                    end
                end

                wr_addr <= wr_addr + (1 << aw_size_reg);
                wr_cnt  <= wr_cnt + 1;

                if (WLAST || wr_cnt == aw_len_reg) begin
                    wr_active <= 0;
                    BVALID    <= 1;
                    BID       <= wr_id;
                    BRESP     <= 2'b00;
                end
            end

            if (BVALID && BREADY) begin
                BVALID <= 0;
            end
        end
    end

    // ----------------------------------
    // Read Address + Data
    // ----------------------------------
    reg rd_active;
    reg [ADDR_WIDTH-1:0] rd_addr;
    reg [7:0]            rd_burst_cnt;
    reg [ID_WIDTH-1:0]   rd_id;
    reg [2:0]            rd_size;

    assign ARREADY = ~rd_active;

    always @(posedge ACLK) begin
        if (ARESET) begin
            rd_active <= 0;
            RVALID    <= 0;
        end else begin
            if (!rd_active && ARVALID && ARREADY) begin
                rd_active     <= 1;
                rd_addr       <= ARADDR;
                rd_burst_cnt  <= ARLEN;
                rd_id         <= ARID;
                rd_size       <= ARSIZE;
            end

            if (rd_active && (!RVALID || (RVALID && RREADY))) begin
                RDATA  <= mem[rd_addr[ADDR_WIDTH-1:6]];
                RID    <= rd_id;
                RRESP  <= 2'b00;
                RVALID <= 1;
                RLAST  <= (rd_burst_cnt == 0);

                if (rd_burst_cnt == 0) begin
                    rd_active <= 0;
                end else begin
                    rd_burst_cnt <= rd_burst_cnt - 1;
                    rd_addr      <= rd_addr + (1 << rd_size);
                end
            end

            if (RVALID && RREADY) begin
                RVALID <= 0;
            end
        end
    end

endmodule
