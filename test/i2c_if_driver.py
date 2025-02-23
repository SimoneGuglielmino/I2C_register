import cocotb
from cocotb.triggers import Timer, FallingEdge, RisingEdge
from cocotb.types import LogicArray,Range
from cocotb.clock import Clock
from cocotb.handle import Force, Release

class i2c_if_driver():
    """I2C driver - to drive the interface pins in the testbench"""
    # This driver is designed to drive the I2C protocoll
    # This includes: 
    #       - Transmitting the START condition
    #       - Transmitting the STOP condition
    #       - Transmitting the RESTART condition
    #       - Transmitting the DEVICE_ADDRESS and the RW bit
    #       - Transmitting or recieving a byte of data

    # To use this driver it needs to be started after the object has been created.
    # This is  done with .start_driver()

    def __init__(self,scl_period,scl,sda_in,sda_out,sda_enable,RST):
        # Interface signals
        self.scl = scl
        self.sda_in = sda_in
        self.sda_out = sda_out
        self.sda_enable = sda_enable
        self.rst = RST   
        self._scl_period = scl_period
        self.scl_clk = Clock(self.scl,self._scl_period,"ns")


    async def start_driver(self):
        # This function starts the clock on SCL and forces both SDA and SCL high.
        self.rst.value = 0
        await Timer(self._scl_period,"ns")
        self.rst.value = 1
        self.sda_in.value = 1
        cocotb.log.debug("I2C Driver creating Clock on scl")
        self.scl_clk_handle = cocotb.start_soon(self.scl_clk.start())
        cocotb.log.debug("Forcing scl to high")
        # Since the I2C protocoll requires SDA and SCL to be high outside of transactions the signals the clock (SCL) is forced high.
        self.scl.value = Force(1)


    async def send_start(self):
        # This function sends the START condition by releasing SCL and after 1/4 of the clock period pulling SDA low
        self.scl.value = Release()
        self.sda_in.value = 1
        await Timer(0.25*self._scl_period,"ns")
        self.sda_in.value = 0
        
    async def send_restart(self):
        # RESTART is the same as START but during "running" SCL
        await FallingEdge(self.scl)
        self.sda_in.value = 1
        await RisingEdge(self.scl)
        await Timer(0.25*self._scl_period,"ns")
        self.sda_in.value = 0

    async def send_addr(self,rw,address):
        # Convert the address into a binstr
        addr = LogicArray(address,Range(0, "to", 6))
        # Send the Address-bits on the falling edge
        for n in range(7):
            await FallingEdge(self.scl)
            self.sda_in.value = addr[n]
            await RisingEdge(self.scl)
        # Send the read/write bit
        await FallingEdge(self.scl)
        self.sda_in.value = rw
        await RisingEdge(self.scl)
        # Check the Slave Ack
        await self.recieve_ack()

    async def write_data(self,data):
        # Convert the data into a binstr
        cocotb.log.debug(f"I2C Driver writing to slave: {hex(data)}")
        byte = LogicArray(data,Range(0, "to", 7))
        # Send the bits of the byte on the falling edge
        for n in range(8):
            await FallingEdge(self.scl)
            self.sda_in.value = byte[n]
            await RisingEdge(self.scl)
        # Ckeck the Slave Ack
        await self.recieve_ack()
    
    async def read_data(self):
        # Emtpy byte to write the recvied data into
        data = LogicArray("XXXXXXXX")
        # Read the slave data on the rising edge
        for n in range(7,-1,-1):
            await RisingEdge(self.scl)
            try:
                assert self.sda_enable.value.binstr == '1', f"Expected DUT to enable sda outputdriver to send DATA"
            except AssertionError as msg:
               cocotb.log.info(msg) 
            data[n] = int(self.sda_out.value.binstr)
        # Check the slave ack
        await self.send_ack()
        cocotb.log.info(f"I2C Driver recieved slave-data: {hex(data.integer)}")
        return data

    async def send_stop(self):
    
        await FallingEdge(self.scl)
        self.sda_in.value = 0
        await RisingEdge(self.scl)
        await Timer(0.25*self._scl_period,"ns")
        self.sda_in.value = 1
        # Hold scl at 1 until next operation
        self.scl.value = Force(1)
        await Timer(0.25*self._scl_period,"ns")

    async def send_ack(self):
        await FallingEdge(self.scl)
        self.sda_in.value = 0
        await RisingEdge(self.scl)

    async def recieve_ack(self):
        await FallingEdge(self.scl)
        # I2C slave sets sda here
        await RisingEdge(self.scl)
        try:
            assert self.sda_enable.value.binstr == '1', f"Expected DUT to enable sda outputdriver to send ACK"
            assert self.sda_out.value.binstr == '0' , f"Ack expected 0 was {self.sda.value.binstr}"
        except AssertionError as msg:
            cocotb.log.info(msg)

    async def reset(self,time):
        self.rst.value = 1
        cocotb.log.debug("Killing the Clock Gen")
        self.scl_clk_handle.kill()
        # Dont force SCL to 1 so start_driver can create a new clock
        self.scl.value = 1
        self.sda_in.value = 1
        await Timer(time,"ns")
        await self.start_driver()
        
