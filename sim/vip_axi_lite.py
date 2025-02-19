import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue, QueueEmpty
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, First

from pyuvm import utility_classes, UVMError
from pyuvm import uvm_sequence_item
from pyuvm import uvm_sequence
from pyuvm import uvm_driver, ConfigDB
from pyuvm import uvm_component
from pyuvm import uvm_subscriber
from pyuvm import uvm_agent, uvm_sequencer

import vsc
from enum import Enum


class AxiLiteBfm(metaclass=utility_classes.Singleton):
    def __init__(self, reset_length=20):
        self.dut = cocotb.top
        self.clk = self.dut.aclk
        cocotb.start_soon(Clock(self.clk, 10, "ns").start())
        self.reset_length = reset_length
        self.driver_queue = Queue()
        self.monitor_queue = Queue()

    def put_driver_queue(self, item):
        self.driver_queue.put_nowait(item)

    async def initialize(self):
        self.dut.aclk.value = 0
        self.dut.aresetn.value = 0
        self.dut.i_axi_awvalid.value = 0
        self.dut.i_axi_awaddr.value = 0
        self.dut.i_axi_awprot.value = 0
        await ClockCycles(self.clk, self.reset_length)
        self.dut.aresetn.value = 1

    async def drive(self):
        await RisingEdge(self.clk)
        try:
            self.item = self.driver_queue.get_nowait()
            await self._drive_write(self.item)
            # todo: add _drive_read(self.item) and Combine
        except QueueEmpty:
            pass

    async def _drive_write(self, item):
        await self._drive_aw(item)

    async def _drive_aw(self, item):
        if (item.kind == Cmd.WRITE):
            await ClockCycles(self.clk, item.awdelay)
            self.dut.i_axi_awvalid.value = 1
            self.dut.i_axi_awaddr.value = item.waddr
            self.dut.i_axi_awprot.value = item.wprot

            await FallingEdge(self.clk)
            ready = cocotb.start_soon(await self.dut.o_axi_awready)
            timeout = cocotb.start_soon(await ClockCycles(self.clk, 100))
            result = First(ready, timeout)
            if result is timeout.complete:
                raise UVMError("Drive AW channel timeout")
        else:
            await RisingEdge(self.clk)

    def start_bfm(self):
        cocotb.start_soon(self.drive())


class Cmd(Enum):
    READ = 0
    WRITE = 1

@vsc.randobj
class AddressWriteSeqItem(uvm_sequence_item):
    def __init__(self, name):
        super().__init__(name)
        self.cmd = vsc.rand_enum_t(Cmd)
        self.awdelay = vsc.rand_bit_t(2)
        self.waddr = vsc.rand_uint64_t()
        self.wprot = vsc.rand_bit_t(3)

    def __eq__(self, rhs):
        return self.cmd == rhs.cmd and self.waddr == rhs.waddr and \
            self.wprot == rhs.wprot
    
    def __str__(self):
        s = f"{self.get_name()}: {self.cmd.name}\n"
        if (self.cmd == Cmd.WRITE):
            s = f"{s}\t{self.waddr:#010X}:\t{self.wdata:#010x}"
            s = f"{s}\tprot:\t{self.wprot:#05b}"
        return s


class AddressWriteSeq(uvm_sequence):
    async def body(self):
        item = AddressWriteSeqItem("item")
        await self.start_item(item)
        item.randomize()
        item.kind = Cmd.WRITE
        await self.finish_item(item)


class AxiLiteDriver(uvm_driver):
    def connect_phase(self):
        self.bfm = ConfigDB().get(self, "", "BFM")
    
    async def run_phase(self):
        await self.bfm.initialize()
        while True:
            item = await self.seq_item_port.get_next_item()
            self.bfm.put_driver_queue(item)
            self.seq_item_port.item_done()


class AxiLiteMonitor(uvm_component):
    ...


class AxiLiteCoverage(uvm_subscriber):
    ...


class AxiLiteAgent(uvm_agent):
    def build_phase(self):
        self.sqr = uvm_sequencer("sqr", self)
        ConfigDB().set(None, "*", "AXI_LITE_SQR", self.sqr)
        self.driver = AxiLiteDriver("driver", self)
        # self.monitor = AxiLiteMonitor("monitor", self)
        # todo: add analysis port and connect to monitor
    
    def connect_phase(self):
        self.driver.seq_item_port.connect(self.sqr.seq_item_export)

