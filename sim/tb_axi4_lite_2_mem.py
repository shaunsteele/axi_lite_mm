# tb_axi4_lite_2_mem.py

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

# TODO: write testbench
# TODO: find solution for byte-wide memory interface (just align address(32 to 8 means truncate 2 LSBs))