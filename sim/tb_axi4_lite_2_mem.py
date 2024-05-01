# tb_axi4_lite_2_mem.py

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteMaster


@cocotb.test()
async def tb_axi4_lite_2_mem(dut):
  cocotb.log.info(f"Starting {tb_axi4_lite_2_mem.__name__}")
  cocotb.log.info(f"Parameters:")
  cocotb.log.info(f"\tAXI_ALEN:\t{dut.AXI_ALEN.value}")
  cocotb.log.info(f"\tMEM_ALEN:\t{dut.MEM_ALEN.value}")
  cocotb.log.info(f"\tDLEN:\t\t{dut.DLEN.value}")
  cocotb.log.info(f"\tSLEN:\t\t{dut.SLEN.value}")

  # Start Clock
  cocotb.start_soon(Clock(dut.clk, 10, "ns").start())

  # Create AXI Driver
  axi = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "axi"),
                      dut.clk,
                      dut.rstn,
                      reset_active_level=False
                      )

  # Initialize Values
  dut.rstn.value = 0
  dut.mem_rdata.value = 0

  # Complete Reset
  await ClockCycles(dut.clk, 10)
  dut.rstn.value = 1

  # Tests:
  # - Concurrent Write then Read
  data = (0x0000, 0xAAAA_AAAA)
  await axi.write(data[0], data[1].to_bytes(4, 'little'))

  await ClockCycles(dut.clk, 5)
  dut.mem_rdata.value = 0xAAAA_AAAA
  await axi.read(0xFFFF, 1)


  # - AW before W Write
  # - W before AW Write
  # - Sequential Writes
  # - Sequential Reads

  await ClockCycles(dut.clk, 10)
