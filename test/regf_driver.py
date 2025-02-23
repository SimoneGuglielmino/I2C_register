import cocotb
from i2c_if_driver import i2c_if_driver
from i2c_common import *

class regf_driver():
    """ I2C protocol driver for easy reading and writing. Implements all protocol steps for the I2C Protocol using the I2C driver from i2c_if_driver.py"""
    def __init__(self,i2c_driver: i2c_if_driver):
        self.i2c_driver = i2c_driver
        
    async def start_drivers(self):
        await self.i2c_driver.start_driver()
    
    async def write_register(self,data,i2c_addr,reg_addr):
        # WRITE transaction consists of START, SEND_ADDRESS, RESTART, WRTIE, STOP
        await self.i2c_driver.send_start()
        await self.i2c_driver.send_addr(AccessType.WR,i2c_addr)
        await self.i2c_driver.write_data(reg_addr)
        await self.i2c_driver.send_restart()
        await self.i2c_driver.send_addr(AccessType.WR,i2c_addr)
        await self.i2c_driver.write_data(data)
        await self.i2c_driver.send_stop()
    
    async def read_register(self,i2c_addr,reg_addr):
        # READ transaction consists of START, SEND_ADDRESS, RESTART, READ, STOP
        await self.i2c_driver.send_start()
        await self.i2c_driver.send_addr(AccessType.WR,i2c_addr)
        await self.i2c_driver.write_data(reg_addr)
        await self.i2c_driver.send_restart()
        await self.i2c_driver.send_addr(AccessType.RD,i2c_addr)
        data = await self.i2c_driver.read_data()
        await self.i2c_driver.send_stop()
        return data
    