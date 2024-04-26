// axi4_lite_2_mem.sv

`default_nettype none

module axi4_lite_2_mem(
  input var clk,
  input var rstn,

  axi4_lite_if.S  axi,
  mem_if.M        mem
);

initial begin
  assert (axi.ALEN >= mem.ALEN)
  assert (axi.DLEN == mem.DLEN)
end

localparam int ALEN = mem.ALEN;
localparam int DLEN = mem.DLEN;
localparam int SLEN = axi.SLEN;

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
    awbuf <= axi.awaddr[ALEN-1:0];
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
    mem.waddr = axi.awaddr;
    mem.wdata = axi.wdata;
  end else if (aw_before_w & w_en) begin
    mem.wen = 1;
    mem.waddr = awbuf;
    mem.wdata = axi.wdata;
  end else if (aw_en & w_before_aw) begin
    mem.wen = 1;
    mem.waddr = axi.awaddr;
    mem.wdata = wbuf;
  end else begin
    mem.wen = 0;
    mem.waddr = 0;
    mem.wdata = 0;
  end
end

// Write Response Channel
always_ff @(posedge clk) begin
  if (!rstn) begin
    axi.bvalid <= 0;
  end else begin
    if ((aw_en & w_en) | (aw_before_w & w_en) | (aw_en & w_before_aw)) begin
      axi.bvalid <= 1;
    end else if (axi.bready) begin
      axi.bvalid <= 0;
    end else begin
      axi.bvalid <= axi.bvalid;
    end
  end
end

assign axi.bresp = 2'b00;


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

// Memory Read
always_comb begin
  mem.ren = axi.arvalid & axi.arready;
end

assign mem.raddr = axi.raddr[ALEN-1:0];
assign axi.rvalid = mem.rvalid;
assign axi.rdata = mem.rdata;
assign axi.rresp = 2'b00;


endmodule
