import cocotb
from cocotb.triggers import RisingEdge,FallingEdge, ReadOnly,Combine,Edge
from cocotb.types import LogicArray,Range
from i2c_common import *
class regf_i2c_driver():
    """ Driver specifically used to drive the registerfile access over I2C in the implemented design"""
    def __init__(self,scl,regf_data_in,regf_data_out,regf_req,regf_rw,regf_ack):
        self.scl = scl
        self.regf_data_in = regf_data_in
        self.regf_data_out = regf_data_out
        self.regf_req = regf_req
        self.regf_ack = regf_ack
        self.regf_rw = regf_rw
        self.data = LogicArray(0,Range(0,"to",7))
        self.address = LogicArray(0,Range(0,"to",7))
        cocotb.log.debug("Regf_i2c_driver initialized")
    
    async def regf_loop(self):
        # Set to outputs to 0
        self.regf_data_out.value = LogicArray(0,Range(0,"to",7))
        self.regf_ack.value= 0
        while True:
            await self.set_addr()
            await self.transaction()
    async def set_addr(self):
        await RisingEdge(self.regf_req)
        self.regf_ack.value = 1
        cocotb.log.debug(f"Addr. Request with req={self.regf_req.value}, rw=AccessType.{AccessType(self.regf_rw.value).name}")
        try:
            assert self.regf_rw.value == AccessType.WR , f"Setting Address expected AccessType.RD was AccessType.{AccessType(self.regf_rw.value).name}"
        except AssertionError as msg:
            print(msg)
        self.address = self.regf_data_in.value
        cocotb.log.debug(f"Set RegisterFile Address to {self.address}")
        await FallingEdge(self.regf_req)
        self.regf_ack.value = 0 
    async def transaction(self):
        await RisingEdge(self.regf_req)
        self.regf_ack.value = 1
        cocotb.log.debug(f"Transaction Request with req={self.regf_req.value}, rw=AccessType.{AccessType(self.regf_rw.value).name}")
        if self.regf_rw.value == AccessType.WR:
            self.data = self.regf_data_in.value
            cocotb.log.debug(f"Regf written {self.data} into the register")
        else:
            self.regf_data_out.value = self.data
            cocotb.log.debug(f"Reading {self.data} from the register")
        await FallingEdge(self.regf_req)
        self.regf_ack.value = 0