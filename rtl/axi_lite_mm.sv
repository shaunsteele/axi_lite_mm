// axi_lite_mm.sv

`default_nettype none

module axi_lite_mm # (
    parameter int ADDR_WIDTH = 64,
    parameter int DATA_WIDTH = 64,
    parameter int STRB_WIDTH = DATA_WIDTH / 8
)(
    input var logic                         aclk,
    input var logic                         aresetn,
    // Write Address Channel
    input var logic                         i_axi_awvalid,
    output var logic                        o_axi_awready,
    input var logic     [ADDR_WIDTH-1:0]    i_axi_awaddr,
    input var logic     [2:0]               i_axi_awprot,
    // Write Data Channel
    input var logic                         i_axi_wvalid,
    output var logic                        o_axi_wready,
    input var logic     [DATA_WIDTH-1:0]    i_axi_wdata,
    input var logic     [STRB_WIDTH-1:0]    i_axi_wstrb,
    // Write Response Channel
    output var logic                        o_axi_bvalid,
    input var logic                         i_axi_bready,
    output var logic    [1:0]               o_axi_bresp,
    // Read Address Channel
    input var logic                         i_axi_arvalid,
    output var logic                        o_axi_arready,
    input var logic     [ADDR_WIDTH-1:0]    i_axi_araddr,
    input var logic     [2:0]               i_axi_arprot,
    // Read Data Channel
    output var logic                        o_axi_rvalid,
    input var logic                         i_axi_rready,
    output var logic    [DATA_WIDTH-1:0]    o_axi_rdata,
    output var logic    [1:0]               o_axi_rresp,

    output var logic                        o_mm_wen,
    output var logic    [ADDR_WIDTH-1:0]    o_mm_waddr,
    output var logic    [DATA_WIDTH-1:0]    o_mm_wdata,
    input var logic                         i_mm_invalid_waddr,
    input var logic                         i_mm_invalid_w_op,
    
    output var logic                        o_mm_ren,
    output var logic    [ADDR_WIDTH-1:0]    o_mm_raddr,
    input var logic     [DATA_WIDTH-1:0]    o_mm_rdata,
    input var logic                         i_mm_invalid_raddr,
    input var logic                         i_mm_invalid_r_op
);

// /* Address and Parameter Control */
// localparam int SLEN = axi.SLEN;
// localparam int Align = $clog2(SLEN);

// initial begin
//   assert (axi.ALEN >= mem.ALEN + Align);
//   assert (axi.DLEN == mem.DLEN);
// end

// localparam int DLEN = mem.DLEN;

// localparam int ALEN = mem.ALEN;

// logic [ALEN-1:0] awaddr;
// assign awaddr = axi.awaddr[ALEN+Align-1:Align];

// // Align Address
// assert property (@(posedge clk) axi.ALEN % axi.SLEN == 0);

// /* Write Channels */
// // Handshake Flags
// logic aw_en;
// logic w_en;
// logic b_en;
// always_comb begin
//   aw_en = axi.awvalid & axi.awready;
//   w_en = axi.wvalid & axi.wready;
//   b_en = axi.bvalid & axi.bready;
// end

// // Write Address Ready
// always_ff @(posedge clk) begin
//   if (!rstn) begin
//     axi.awready <= 1;
//   end else begin
//     // Lowers if aw comes before w, raises once w is accepted
//     if (axi.awready) begin
//       axi.awready <= ~(axi.awvalid & ~axi.wvalid);
//     end else begin
//       axi.awready <= w_en;
//     end
//   end
// end

// // Write Data Ready
// always_ff @(posedge clk) begin
//   if (!rstn) begin
//     axi.wready <= 1;
//   end else begin
//     if (axi.wready) begin
//       axi.wready <= ~(~axi.awvalid & axi.wvalid);
//     end else begin
//       axi.wready <= aw_en;
//     end
//   end
// end

// // Handshake Timing Latches
// logic aw_before_w;
// always_ff @(posedge clk) begin
//   if (!rstn) begin
//     aw_before_w <= 0;
//   end else begin
//     if (aw_before_w) begin
//       aw_before_w <= ~w_en;
//     end else begin
//       aw_before_w <= aw_en & ~w_en;
//     end
//   end
// end

// logic w_before_aw;
// always_ff @(posedge clk) begin
//   if (!rstn) begin
//     w_before_aw <= 0;
//   end else begin
//     if (w_before_aw) begin
//       w_before_aw <= ~aw_en;
//     end else begin
//       w_before_aw <= ~aw_en & w_en;
//     end
//   end
// end

// // Write Address Buffer
// logic [ALEN-1:0]  awbuf;
// always_ff @(posedge clk) begin
//   if (aw_en & ~w_en) begin
//     awbuf <= awaddr[ALEN-1:0];
//   end else begin
//     awbuf <= awbuf;
//   end
// end

// // Write Strobe Byte Enable
// logic [DLEN-1:0]  sbuf;
// always_comb begin
//   for (int i=0; i < SLEN; i++) begin
//     if (axi.wstrb[i]) begin
//       sbuf[i*8+:8] = axi.wdata[i*8+:8];
//     end else begin
//       sbuf[i*8+:8] = 0;
//     end
//   end
// end

// // Write Data Buffer
// logic [DLEN-1:0]  wbuf;
// always_ff @(posedge clk) begin
//   if (~aw_en & w_en) begin
//     wbuf <= sbuf;
//   end else begin
//     wbuf <= wbuf;
//   end
// end

// // Memory Write
// always_comb begin
//   if (aw_en & w_en) begin
//     mem.wen = 1;
//     mem.waddr = awaddr;
//     mem.wdata = axi.wdata;
//   end else if (aw_before_w & w_en) begin
//     mem.wen = 1;
//     mem.waddr = awbuf;
//     mem.wdata = axi.wdata;
//   end else if (aw_en & w_before_aw) begin
//     mem.wen = 1;
//     mem.waddr = awaddr;
//     mem.wdata = wbuf;
//   end else begin
//     mem.wen = 0;
//     mem.waddr = 0;
//     mem.wdata = 0;
//   end
// end

// // Successful Write Request
// logic wreq;
// always_comb begin
//   wreq = (aw_en & w_en) | (aw_before_w & w_en) | (aw_en & w_before_aw);
// end

// // Write Response Queue
// logic [ALEN-1:0]  reqs;
// logic [ALEN-1:0]  reqs_next;
// always_comb begin
//   if (wreq & b_en) begin
//     reqs_next = reqs;
//   end else if (wreq) begin
//     reqs_next = {reqs[ALEN-2:0], 1'b1};
//   end else if (b_en) begin
//     reqs_next = {1'b0, reqs[ALEN-1:1]};
//   end else begin
//     reqs_next = reqs;
//   end
// end

// always_ff @(posedge clk) begin
//   if (!rstn) begin
//     reqs <= 0;
//   end else begin
//     reqs <= reqs_next;
//   end
// end

// // Write Response Valid
// always_ff @(posedge clk) begin
//   if (!rstn) begin
//     axi.bvalid <= 0;
//   end else begin
//     if (axi.bvalid) begin
//       axi.bvalid <= &reqs_next;
//     end else begin
//       axi.bvalid <= wreq;
//     end
//   end
// end

// // Write Response Data
// localparam bit [1:0]  OKAY = 2'b00;
// localparam bit [1:0]  SLVERR = 2'b10;
// always_ff @(posedge clk) begin
//   if (!rstn) begin
//     axi.bresp <= OKAY;
//   end else begin
//     if (axi.bresp == SLVERR) begin
//       axi.bresp <= SLVERR;
//     end else begin
//       if (&reqs_next & wreq) begin
//         axi.bresp <= SLVERR;
//       end else begin
//         axi.bresp <= OKAY;
//       end
//     end
//   end
// end


// /* Read Channels */
// // Read Address Ready
// always_ff @(posedge clk) begin
//   if (!rstn) begin
//     axi.arready <= 1;
//   end else begin
//     if (axi.arready) begin
//       axi.arready <= ~axi.arvalid;
//     end else begin
//       axi.arready <= axi.rvalid & axi.rready;
//     end
//   end
// end

// // Memory Read Enable
// always_comb begin
//   mem.ren = axi.arvalid & axi.arready;
// end


// // Read Address Buffer
// logic [axi.ALEN-1:0] araddr_buf;
// always_ff @(posedge clk) begin
//   if (mem.ren) begin
//     araddr_buf <= axi.araddr;
//   end else begin
//     araddr_buf <= araddr_buf;
//   end
// end

// // Memory Read Address
// always_comb begin
//   if (mem.ren) begin
//     mem.raddr = axi.araddr[ALEN+Align-1:Align];
//   end else begin
//     mem.raddr = araddr_buf[ALEN+Align-1:Align];
//   end
// end


// // Read Data Valid Latch
// always_ff @(posedge clk) begin
//   if (!rstn) begin
//     axi.rvalid <= 0;
//   end else begin
//     if (axi.rvalid) begin
//       axi.rvalid <= ~axi.rready;
//     end else begin
//       axi.rvalid <= mem.ren;
//     end
//   end
// end

// // Read Data Latch
// assign axi.rdata = mem.rdata;
// assign axi.rresp = 2'b00;


endmodule
