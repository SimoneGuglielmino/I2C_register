import vsc
from enum import IntEnum

class AccessType(IntEnum):
    """ Type of access: read (RD) or write (WR)"""
    WR = 0
    RD = 1

# Types for the driver
class DriverType(IntEnum):
    CONSUMER = 0
    PRODUCER = 1
    

@vsc.randobj
class rand_transaction():
    def __init__(self,ADDRESS_WIDTH,DATA_WIDTH):
        self.rw = vsc.rand_bit_t()
        self.address = vsc.rand_int_t()
        self.ADDRESS_WIDTH = ADDRESS_WIDTH
        self.DATA_WIDTH = DATA_WIDTH
        self.data = vsc.rand_int_t()
    @vsc.constraint
    def const_address_data(self):
        self.address >= 0
        self.address < 2**int(self.ADDRESS_WIDTH)
        self.data >= 0
        self.data < 2**int(self.DATA_WIDTH)
    def __str__(self):
        return f"{AccessType(self.rw).name} at addr: {self.address}, data: {self.data}"
    


