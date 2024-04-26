// axi4_lite_if.sv

`default_nettype none

interface axi4_lite_if # (
  parameter int ALEN  = 32,
  parameter int DLEN  = 32,
  parameter int SLEN  = DLEN / 8
)(
  input var aclk,
  input var aresetn
);

// Write Address Channel
logic             awvalid;
logic             awready;
logic [ALEN-1:0]  awaddr;
logic [2:0]       awprot;

// Write Data Channel
logic             wvalid;
logic             wready;
logic [DLEN-1:0]  wdata;
logic [SLEN-1:0]  wstrb;

// Write Response Channel
logic             bvalid;
logic             bready;
logic [1:0]       bresp;

// Read Address Channel
logic             arvalid;
logic             arready;
logic [ALEN-1:0]  araddr;
logic [2:0]       arprot;

// Read Data Channel
logic             rvalid;
logic             rready;
logic [DLEN-1:0]  rdata;
logic [1:0]       rresp;

// Modports
modport M (
  input aclk, aresetn,
  output awvalid, awaddr, awprot, input awready,
  output wvalid, wdata, wstrb, input wready,
  output bready, input bvalid, bresp,
  output arvalid, araddr, arprot, input arready,
  output rready, input rvalid, rresp
);

modport S (
  input aclk, aresetn,
  input awvalid, awaddr, awprot, output awready,
  input wvalid, wdata, wstrb, output wready,
  input bready, output bvalid, bresp,
  input arvalid, araddr, arprot, output arready,
  input rready, output rvalid, rresp
);

// Clocking Blocks
clocking m_drv_cb @(posedge aclk);
  default input #2 output #2;
  output awvalid;
  input awready;
  output awaddr;
  output awprot;
  output wvalid;
  input wready;
  output wdata;
  output wstrb;
  input bvalid;
  output bready;
  input bresp;
  output arvalid;
  input arready;
  output araddr;
  output arprot;
  input rvalid;
  output rready;
  input rdata;
  input rresp;
endclocking
modport M_DRV (clocking m_drv_cb, input aclk, input aresetn);

clocking s_drv_cb @(posedge aclk);
  default input #2 output #2;
  input awvalid;
  output awready;
  input awaddr;
  input awprot;
  input wvalid;
  output wready;
  input wdata;
  input wstrb;
  output bvalid;
  input bready;
  input bresp;
  input arvalid;
  output arready;
  input araddr;
  input arprot;
  output rvalid;
  input rready;
  output rdata;
  output rresp;
endclocking
modport S_DRV (clocking s_drv_cb, input aclk, input aresetn);

clocking mon_cb @(posedge aclk);
  default input #2 output #2;
  input awvalid;
  input awready;
  input awaddr;
  input awprot;
  input wvalid;
  input wready;
  input wdata;
  input wstrb;
  input bvalid;
  input bready;
  input bresp;
  input arvalid;
  input arready;
  input araddr;
  input arprot;
  input rvalid;
  input rready;
  input rdata;
  input rresp;
endclocking
modport MON (clocking mon_cb, input aclk, input aresetn);

endinterface
