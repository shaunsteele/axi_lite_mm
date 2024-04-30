// mem_if.sv

`default_nettype none

interface mem_if #(
  parameter int ALEN = 1,
  parameter int DLEN = 8
)(
  input var clk,
  input var rstn
);

logic             wen;
logic [ALEN-1:0]  waddr;
logic [DLEN-1:0]  wdata;

logic             ren;
logic [ALEN-1:0]  raddr;
logic [DLEN-1:0]  rdata;

modport M (
  input clk, rstn,
  output wen, waddr, wdata,
  output ren, raddr, input rdata
);
  
modport S (
  input clk, rstn,
  input wen, waddr, wdata,
  input ren, raddr, output rdata
);

endinterface