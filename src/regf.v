/*
    This registerfile follows a simple protocol:
        1. Set the address to read/write from
        2. read/write from/to that address
    Each read/write always has these two steps.
    The first step (address set) is always a write.
    Both steps are exectued as per the data_protocol described below

    The data_protocol follows a asynchronous bundled data handshake protocol.
    There are two datalines:
        - read_data
        - write_data
    read_data is written by the registerfile for read operations, when the registerfile acknowledges the request
    write_data is written by the i2c_interface for write operations, when the i2c_interface sends the request

    The rw signal specifies if the operation is a read or a write with:
        0 = Write
        1 = Read

    The data_protocol has the following steps:
        1. The master (i2c_interface) pulls request high and sets the rw signal and the write_data (if write).
        2. Once the slave(registerfile) has recieved data on write_data(write) or has set read_data (read), it pulls the ack high.
        3. The master releases request and once released the slave releases ack.

    This design used the following variables
    Variable            Type    Description
    ----------------------------------------------
    regf_write_data     Input   Data to write from i2c_interface to registerfile
    regf_rw             Input   Specifies read/write operation
    regf_req            Input   request
    regf_ack            Output  acknowledge
    out_regf_read_data  Output  Data to read from registerfile
*/
module reg_file #(
  // standards for the parameters
  parameter DATA_WIDTH = 8,
  parameter ADDR_WIDTH = 8,
  parameter _REGF_LENGTH = (1 << ADDR_WIDTH)*DATA_WIDTH-1
)(
    // Interface to the i2c slave
    input rst,
    input [7:0] regf_write_data,
    output wire [7:0] out_regf_read_data,
    input regf_req,
    input regf_rw
  // Registerfile
);

// States
localparam IDLE                 = 0; // Wait for address
localparam IDLE_TRANSACTION     = 1; // Wait for read/write access

// Output Drivers
// internal registers to drive the outputs
reg[7:0] out_reg = 0;
reg[7:0] regf_read_data;
reg[_REGF_LENGTH:0] reg_array;
// Drive the outputs
assign out_regf_read_data = regf_read_data;


// State variable
reg[7:0] state = 0;
// Pointer keep track where to read
reg[ADDR_WIDTH-1:0] reg_pointer = 0;

always @(posedge regf_req or negedge rst) begin
    if(!rst) begin
        regf_read_data <= 0;
        state <= 0;
        reg_array <= 0;
        reg_pointer <= 0;
    end else begin
        regf_read_data <= reg_array[reg_pointer*DATA_WIDTH +: DATA_WIDTH];
        if (regf_req) begin
            case(state)
                IDLE: begin
                    if (regf_rw == 0) begin
                        reg_pointer <= regf_write_data[ADDR_WIDTH-1:0];
                        state <= IDLE_TRANSACTION;
                    end
                end
                IDLE_TRANSACTION: begin
                    if (regf_rw == 0) begin
                        reg_array[reg_pointer*DATA_WIDTH +: DATA_WIDTH] <= regf_write_data;
                        regf_read_data <= regf_read_data;
                    end
                    state <= IDLE;
                end
            endcase
        end
    end
end

endmodule

