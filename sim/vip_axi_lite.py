import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue, QueueEmpty
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Combine, First

from pyuvm import utility_classes, UVMError
from pyuvm import uvm_sequence_item
from pyuvm import uvm_sequence
from pyuvm import uvm_driver, ConfigDB
from pyuvm import uvm_component
from pyuvm import uvm_subscriber
from pyuvm import uvm_agent, uvm_sequencer

import vsc
import warnings
from enum import Enum

warnings.filterwarnings("ignore", category=DeprecationWarning)

# transaction
class Cmd(Enum):
    READ = 0
    WRITE = 1

@vsc.randobj
class AxiLiteSeqItem(uvm_sequence_item):
    def __init__(self, name):
        super().__init__(name)
        self.cmd = vsc.rand_enum_t(Cmd)
        self.awdelay = vsc.rand_bit_t(2)
        self.wdelay = vsc.rand_bit_t(2)
        self.bdelay = vsc.rand_bit_t(2)
        self.addr = vsc.rand_uint64_t()
        self.prot = vsc.rand_bit_t(3)
        self.data = vsc.rand_uint64_t()
        self.wstrb = vsc.rand_uint8_t()
        self.resp = vsc.rand_bit_t(2)

    @vsc.constraint
    def cmd_c(self):
        self.cmd == Cmd.WRITE
    
    @vsc.constraint
    def addr_c(self):
        self.addr < 0x1000

    @vsc.constraint
    def prot_c(self):
        self.prot == 0b000

    @vsc.constraint
    def strb_c(self):
        self.wstrb == 0xFF

    @vsc.constraint
    def resp_c(self):
        self.resp == 0

    def copy_addr(self, rhs):
        self.addr = rhs.addr
    
    def copy_prot(self, rhs):
        self.prot = rhs.prot
    
    def copy_data(self, rhs):
        self.data = rhs.data

    def copy_wstrb(self, rhs):
        self.wstrb = rhs.wstrb
    
    def copy_resp(self, rhs):
        self.resp = rhs.resp

    def __eq__(self, rhs):
        if self.cmd != rhs.cmd:
            return False
        if self.addr != rhs.addr and self.prot != rhs.prot:
            return False
        if self.data != rhs.data and self.resp != rhs.resp:
            return False
        return True
            
    def __str__(self):
        s = f"{self.get_type_name()}: {self.cmd.name}\n"
        s = f"{s}\t{self.prot:#05b}\t{self.addr:#010x}:"
        s = f"{s}\t{self.data:#010x}\t{self.resp:#04b}\n"
        s = f"{s}\tawdelay: {self.awdelay}\twdelay: {self.wdelay}"
        return s


# sequence library
class WriteSeq(uvm_sequence):
    async def body(self):
        item = AxiLiteSeqItem("item")
        await self.start_item(item)
        item.randomize()
        item.kind = Cmd.WRITE
        await self.finish_item(item)


# agent
class AxiLiteBfm(metaclass=utility_classes.Singleton):
    def __init__(self, reset_length=20):
        self.dut = cocotb.top
        self.clk = self.dut.aclk
        cocotb.start_soon(Clock(self.clk, 10, "ns").start())
        self.reset_length = reset_length
        self.driver_queue = Queue()
        self.monitor_queue = Queue()

    async def put_driver_queue(self, item):
        self.driver_queue.put_nowait(item)

    async def initialize(self):
        self.dut.aclk.value = 0
        self.dut.aresetn.value = 0
        self.dut.i_axi_awvalid.value = 0
        self.dut.i_axi_awaddr.value = 0
        self.dut.i_axi_awprot.value = 0
        self.dut.i_axi_wvalid.value = 0
        self.dut.i_axi_wdata.value = 0
        self.dut.i_axi_wstrb.value = 0
        self.dut.i_axi_bready.value = 0
        await ClockCycles(self.clk, self.reset_length)
        self.dut.aresetn.value = 1

    async def drive(self):
        while True:
            await RisingEdge(self.clk)
            try:
                item = self.driver_queue.get_nowait()
                await self._drive_write(item)
                # todo: add _drive_read(self.item) and Combine
            except QueueEmpty:
                pass

    async def _drive_write(self, item):
        await Combine(
            cocotb.start_soon(self._drive_aw(item)),
            cocotb.start_soon(self._drive_w(item))
        )
        await self._drive_b(item)

    async def _wait_for_signal(self, signal, level=1,timeout=100):
        ct = 0
        while int(signal.value) != level and ct < timeout:
            await FallingEdge(self.clk)
            ct += 1
        if ct >= timeout:
            raise TimeoutError()

    async def _drive_aw(self, item):
        if item.kind == Cmd.WRITE:
            await ClockCycles(self.clk, item.awdelay)
            self.dut.i_axi_awvalid.value = 1
            self.dut.i_axi_awaddr.value = item.addr
            self.dut.i_axi_awprot.value = item.prot

            await FallingEdge(self.clk)
            await self._wait_for_signal(self.dut.o_axi_awready)
        else:
            await RisingEdge(self.clk)

    async def _drive_w(self, item):
        if item.kind == Cmd.WRITE:
            await ClockCycles(self.clk, item.wdelay)
            self.dut.i_axi_wvalid.value = 1
            self.dut.i_axi_wdata.value = item.data
            self.dut.i_axi_wstrb.value = item.wstrb

            await FallingEdge(self.clk)
            await self._wait_for_signal(self.dut.o_axi_wready)
        else:
            await RisingEdge(self.clk)

    async def _drive_b(self, item):
        if item.kind == Cmd.WRITE:
            await ClockCycles(self.clk, item.bdelay)
            self.dut.i_axi_bready.value = 1

            await FallingEdge(self.clk)
            await self._wait_for_signal(self.dut.o_axi_bvalid)
        else:
            await RisingEdge(self.clk)

    async def monitor(self):
        while True:
            w = cocotb.start_soon(self._monitor_write())
            result = await First(w)
            cocotb.log.info(w.done())
            cocotb.log.info("monitor")
            if result is w.done():
                self.monitor_queue.put_nowait(w.result())
                cocotb.log.info(f"monitor\n{w.result()}")

    async def _monitor_write(self):
        mon_aw_task = cocotb.start_soon(self._monitor_aw())
        mon_w_task = cocotb.start_soon(self._monitor_w())
        mon_b_task = cocotb.start_soon(self._monitor_b())
        await Combine(mon_aw_task, mon_w_task, mon_b_task)
        item = AxiLiteSeqItem("item")
        item.cmd = Cmd.WRITE
        item.copy_addr(mon_aw_task.result())
        item.copy_prot(mon_aw_task.result())
        item.copy_data(mon_w_task.result())
        item.copy_wstrb(mon_w_task.result())
        item.copy_resp(mon_b_task.result())
        return item

    async def _monitor_aw(self):
        while not(int(self.dut.i_axi_awvalid.value) and int(self.dut.o_axi_awready.value)):
            await FallingEdge(self.clk)
        item = AxiLiteSeqItem("item")
        item.addr = int(self.dut.i_axi_awaddr.value)
        item.prot = int(self.dut.i_axi_awprot.value)
        cocotb.log.info(f"_monitor_aw:\t{item.addr:#010x}\t{item.prot:#05b}")
        return item

    async def _monitor_w(self):
        while not(int(self.dut.i_axi_wvalid.value) and int(self.dut.o_axi_wready.value)):
            await FallingEdge(self.clk)
        item = AxiLiteSeqItem("item")
        item.data = int(self.dut.i_axi_wdata.value)
        item.wstrb = int(self.dut.i_axi_wstrb.value)
        cocotb.log.info(f"_monitor_w:\t{item.data:#010x}\t{item.wstrb:#04x}")
        return item
    
    async def _monitor_b(self):
        while not(int(self.dut.o_axi_bvalid.value) and int(self.dut.i_axi_bready.value)):
            await FallingEdge(self.clk)
        item = AxiLiteSeqItem("item")
        item.resp = int(self.dut.o_axi_bresp.value)
        cocotb.log.info(f"_monitor_b:\t{item.resp:#04b}")
        return item

    def start_bfm(self):
        cocotb.start_soon(self.drive())
        cocotb.start_soon(self.monitor())


class AxiLiteDriver(uvm_driver):
    def connect_phase(self):
        self.bfm = ConfigDB().get(self, "", "BFM")
    
    async def run_phase(self):
        await self.bfm.initialize()
        while True:
            item = await self.seq_item_port.get_next_item()
            await self.bfm.put_driver_queue(item)
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

