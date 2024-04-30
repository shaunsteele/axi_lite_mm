// tb_axi4_lite_2_mem_top.sv

`default_nettype none

module tb_axi4_lite_2_mem_top #(
  parameter int AXI_ALEN  = 32,
  parameter int MEM_ALEN  = 2,
  parameter int DLEN      = 32,
  parameter int SLEN      = DLEN / 8
)(
  input var                         clk,
  input var                         rstn,

  input var                         axi_awvalid,
  output var logic                  axi_awready,
  input var         [AXI_ALEN-1:0]  axi_awaddr,

  input var                         axi_wvalid,
  output var logic                  axi_wready,
  input var         [DLEN-1:0]      axi_wdata,
  input var         [SLEN-1:0]      axi_wstrb,

  output var logic                  axi_bvalid,
  input var                         axi_bready,
  output var logic  [1:0]           axi_bresp,

  input var                         axi_arvalid,
  output var logic                  axi_arready,
  input var         [AXI_ALEN-1:0]  axi_araddr,

  output var logic                  axi_rvalid,
  input var                         axi_rready,
  output var logic  [DLEN-1:0]      axi_rdata,
  output var logic  [1:0]           axi_rresp,

  output var logic                  mem_wen,
  output var logic  [MEM_ALEN-1:0]  mem_waddr,
  output var logic  [DLEN-1:0]      mem_wdata,

  output var logic                  mem_ren,
  output var logic  [MEM_ALEN-1:0]  mem_raddr,
  input var         [DLEN-1:0]      mem_rdata
);

// AXI4-Lite Interface
axi4_lite_if # (.ALEN(AXI_ALEN), .DLEN(DLEN)) axi(.aclk(clk), .aresetn(rstn));

// AXI4-Lite Connections
assign axi.awvalid = axi_awvalid;
assign axi_awready = axi.awready;
assign axi.awaddr = axi_awaddr;
assign axi.awprot = 3'b000;
assign axi.wvalid = axi_wvalid;
assign axi_wready = axi.wready;
assign axi.wdata = axi_wdata;
assign axi.wstrb = axi_wstrb;
assign axi_bvalid = axi.bvalid;
assign axi.bready = axi_bready;
assign axi_bresp = axi.bresp;
assign axi.arvalid = axi_arvalid;
assign axi_arready = axi.arready;
assign axi.araddr = axi_araddr;
assign axi.arprot = 3'b000;
assign axi_rvalid = axi.rvalid;
assign axi.rready = axi_rready;
assign axi_rdata = axi.rdata;
assign axi_rresp = axi.rresp;


// Memory Interface
mem_if # (.ALEN(MEM_ALEN), .DLEN(DLEN)) mem(.clk(clk), .rstn(rstn));

// Memory Connections
assign mem_wen = mem.wen;
assign mem_waddr = mem.waddr;
assign mem_wdata = mem.wdata;
assign mem_ren = mem.ren;
assign mem_raddr = mem.raddr;
assign mem.rdata = mem_rdata;


// DUT
axi4_lite_2_mem u_DUT (
  .clk  (clk),
  .rstn (rstn),
  .axi  (axi),
  .mem  (mem)
);

endmodule
