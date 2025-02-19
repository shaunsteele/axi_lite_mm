# tb_axi_lite_mm.py

from cocotb.triggers import ClockCycles

import pyuvm
from pyuvm import uvm_test, ConfigDB, uvm_sequence, s14_15_python_sequences

from vip_axi_lite import AxiLiteBfm, AxiLiteAgent, AddressWriteSeq


class VirtualSequence(uvm_sequence):
    async def body(self):
        seq = AddressWriteSeq("seq")
        await seq.start()


@pyuvm.test()
class AddressWriteTest(uvm_test):
    def build_phase(self):
        self.bfm = AxiLiteBfm()
        ConfigDB().set(None, "*", "BFM", self.bfm)
        self.bfm.start_bfm()
        self.agent = AxiLiteAgent("agent", self)
        # todo: define environment

    async def run_phase(self):
        self.raise_objection()
        self.seq = VirtualSequence("seq")
        await ClockCycles(self.bfm.clk, 100)
        self.drop_objection()

    

