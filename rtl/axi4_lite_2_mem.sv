// axi4_lite_2_mem.sv

`default_nettype none

module axi4_lite_2_mem(
  input var clk,
  input var rstn,

  axi4_lite_if.S  axi,
  mem_if.M        mem
);

/* Address and Parameter Control */
localparam int SLEN = axi.SLEN;
localparam int Align = $clog2(SLEN);

initial begin
  assert (axi.ALEN >= mem.ALEN + Align);
  assert (axi.DLEN == mem.DLEN);
end

localparam int DLEN = mem.DLEN;

localparam int ALEN = mem.ALEN;

logic [ALEN-1:0] awaddr;
logic [ALEN-1:0] araddr;
assign awaddr = axi.awaddr[ALEN+Align:Align];
assign araddr = axi.araddr[ALEN+Align:Align];

// Align Address
assert property (@(posedge clk) axi.ALEN % axi.SLEN == 0);

/* Write Channels */
// Handshake Flags
logic aw_en;
logic w_en;
logic b_en;
always_comb begin
  aw_en = axi.awvalid & axi.awready;
  w_en = axi.wvalid & axi.wready;
  b_en = axi.bvalid & axi.bready;
end

// Write Address Ready
always_ff @(posedge clk) begin
  if (!rstn) begin
    axi.awready <= 1;
  end else begin
    // Lowers if aw comes before w, raises once w is accepted
    if (axi.awready) begin
      axi.awready <= ~(axi.awvalid & ~axi.wvalid);
    end else begin
      axi.awready <= w_en;
    end
  end
end

// Write Data Ready
always_ff @(posedge clk) begin
  if (!rstn) begin
    axi.wready <= 1;
  end else begin
    if (axi.wready) begin
      axi.wready <= ~(~axi.awvalid & axi.wvalid);
    end else begin
      axi.wready <= aw_en;
    end
  end
end

// Handshake Timing Latches
logic aw_before_w;
always_ff @(posedge clk) begin
  if (!rstn) begin
    aw_before_w <= 0;
  end else begin
    if (aw_before_w) begin
      aw_before_w <= ~w_en;
    end else begin
      aw_before_w <= aw_en & ~w_en;
    end
  end
end

logic w_before_aw;
always_ff @(posedge clk) begin
  if (!rstn) begin
    w_before_aw <= 0;
  end else begin
    if (w_before_aw) begin
      w_before_aw <= ~aw_en;
    end else begin
      w_before_aw <= ~aw_en & w_en;
    end
  end
end

// Write Address Buffer
logic [ALEN-1:0]  awbuf;
always_ff @(posedge clk) begin
  if (aw_en & ~w_en) begin
    awbuf <= awaddr[ALEN-1:0];
  end else begin
    awbuf <= awbuf;
  end
end

// Write Strobe Byte Enable
logic [DLEN-1:0]  sbuf;
always_comb begin
  for (int i=0; i < SLEN; i++) begin
    if (axi.wstrb[i]) begin
      sbuf[i*8+:8] = axi.wdata[i*8+:8];
    end else begin
      sbuf[i*8+:8] = 0;
    end
  end
end

// Write Data Buffer
logic [DLEN-1:0]  wbuf;
always_ff @(posedge clk) begin
  if (~aw_en & w_en) begin
    wbuf <= sbuf;
  end else begin
    wbuf <= wbuf;
  end
end

// Memory Write
always_comb begin
  if (aw_en & w_en) begin
    mem.wen = 1;
    mem.waddr = awaddr;
    mem.wdata = axi.wdata;
  end else if (aw_before_w & w_en) begin
    mem.wen = 1;
    mem.waddr = awbuf;
    mem.wdata = axi.wdata;
  end else if (aw_en & w_before_aw) begin
    mem.wen = 1;
    mem.waddr = awaddr;
    mem.wdata = wbuf;
  end else begin
    mem.wen = 0;
    mem.waddr = 0;
    mem.wdata = 0;
  end
end

// Successful Write Request
logic wreq;
always_comb begin
  wreq = (aw_en & w_en) | (aw_before_w & w_en) | (aw_en & w_before_aw);
end

// Write Response Queue
logic [ALEN-1:0]  reqs;
logic [ALEN-1:0]  reqs_next;
always_comb begin
  if (wreq & b_en) begin
    reqs_next = reqs;
  end else if (wreq) begin
    reqs_next = {reqs[ALEN-2:0], 1};
  end else if (b_en) begin
    reqs_next = {0, reqs[ALEN-1:1]};
  end else begin
    reqs_next = reqs;
  end
end

always_ff @(posedge clk) begin
  if (!rstn) begin
    reqs <= 0;
  end else begin
    reqs <= reqs_next;
  end
end

// Write Response Valid
always_ff @(posedge clk) begin
  if (!rstn) begin
    axi.bvalid <= 0;
  end else begin
    if (axi.bvalid) begin
      axi.bvalid <= &reqs_next;
    end else begin
      axi.bvalid <= wreq;
    end
  end
end

// Write Response Data
localparam bit [1:0]  OKAY = 2'b00;
localparam bit [1:0]  SLVERR = 2'b10;
always_ff @(posedge clk) begin
  if (!rstn) begin
    axi.bresp <= OKAY;
  end else begin
    if (axi.bresp == SLVERR) begin
      axi.bresp <= SLVERR;
    end else begin
      if (&reqs_next & wreq) begin
        axi.bresp <= SLVERR;
      end else begin
        axi.bresp <= OKAY;
      end
    end
  end
end


/* Read Channels */
// Read Address Ready
always_ff @(posedge clk) begin
  if (!rstn) begin
    axi.arready <= 1;
  end else begin
    if (axi.arready) begin
      axi.arready <= ~axi.arvalid;
    end else begin
      axi.arready <= axi.rvalid & axi.rready;
    end
  end
end

// Memory Read Enable
always_comb begin
  mem.ren = axi.arvalid & axi.arready;
end

// Memory Read Address
assign mem.raddr = araddr;

// Read Data Valid Latch
always_ff @(posedge clk) begin
  if (!rstn) begin
    axi.rvalid <= 0;
  end else begin
    if (axi.rvalid) begin
      axi.rvalid <= ~axi.rready;
    end else begin
      axi.rvalid <= mem.rvalid;
    end
  end
end

// Memory Read Data Buffer
logic [DLEN-1:0]  rdata_buf;
always_ff @(posedge clk) begin
  if (!axi.rready) begin
    rdata_buf <= mem.rdata;
  end else begin
    rdata_buf <= rdata_buf;
  end
end

// Read Data Latch
always_ff @(posedge clk) begin
  if (axi.rready) begin
    axi.rdata <= mem.rdata;
  end else begin
    axi.rdata <= rdata_buf;
  end
end

assign axi.rresp = 2'b00;


endmodule
