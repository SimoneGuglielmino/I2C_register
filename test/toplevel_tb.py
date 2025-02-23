import cocotb
import cocotb.triggers
import vsc
from i2c_common import *
from i2c_if_driver import i2c_if_driver 
from regf_driver import regf_driver

# Parameters
_I2C_SLAVE_ADDR_ = int(0b0101010)
_MAX_ITR_NBR = 500
_ADDR_WIDTH = 4
_DATA_WIDTH = 8


@vsc.randobj
class toplevel_test():
    def __init__(self,dut):
        self.itr_nbr = vsc.rand_int_t()
        self.dut = dut 
    @vsc.constraint
    def max_itr_nbr(self):
        self.itr_nbr <= _MAX_ITR_NBR
        self.itr_nbr > 0

    async def run_test(self):
        # Dictionary to represent the current state of the regsiterfile
        regf_reference = dict()
        transaction = rand_transaction(_ADDR_WIDTH,_DATA_WIDTH)
        self.randomize()

        i2c_driver = i2c_if_driver(scl_period   = 4,
                                   scl          = self.dut.clk,
                                   sda_in       = self.dut.uio_in[0],
                                   sda_out      = self.dut.uio_out[0],
                                   sda_enable   = self.dut.uio_oe[0],
                                   RST          = self.dut.rst_n)
        protocol_driver = regf_driver(i2c_driver) 
        await protocol_driver.start_drivers()
        # Write into a random register so there is always something to read
        transaction.randomize()
        regf_reference[transaction.address] = transaction.data

        cocotb.log.info("----Writing to the Registerfile----")
        cocotb.log.info(f"Registerfile: writing {hex(transaction.data)} to {hex(transaction.address)}")
        await protocol_driver.write_register(transaction.data,_I2C_SLAVE_ADDR_,transaction.address)

        cocotb.log.info(f"Testbench: sending {self.itr_nbr} Transactions")
        for _ in range(self.itr_nbr):
            transaction = rand_transaction(_ADDR_WIDTH,_DATA_WIDTH)
            transaction.randomize()
            cocotb.log.info(f"pre_sel: {transaction}")
            if transaction.rw == AccessType.RD:
                with transaction.randomize_with():
                    transaction.address in list(regf_reference.keys())
                    transaction.rw == AccessType.RD
                cocotb.log.info(f"read_tras: {transaction}")
                cocotb.log.info("----Reading from the Registerfile----")
                cocotb.log.info(f"Registerfile: Reading from address: {hex(transaction.address)}")
                data = await protocol_driver.read_register(_I2C_SLAVE_ADDR_,transaction.address)
                assert regf_reference[transaction.address] == data.integer , f"register {hex(transaction.address)} was expected to hold {hex(regf_reference[transaction.address])}, held {hex(data.integer)}"
                cocotb.log.info(f"Registerfile: got {hex(data.integer)}")


            elif transaction.rw == AccessType.WR:
                regf_reference[transaction.address] = transaction.data
                cocotb.log.info("----Writing to the Registerfile----")
                cocotb.log.info(f"Registerfile: writing {hex(transaction.data)} to {hex(transaction.address)}")
                await protocol_driver.write_register(transaction.data,_I2C_SLAVE_ADDR_,transaction.address)

@cocotb.test()
async def test(dut):
    cocotb.log.level = cocotb.logging.DEBUG
    test_inst = toplevel_test(dut)
    await test_inst.run_test()
