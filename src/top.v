module top #(
    // Width of the individual registers, 
    // this should be kept at 8 (as i2c-pkg is 8bit)
    parameter DATA_WIDTH = 8, 
    // This defines the addresss space of the register file
    parameter ADDR_WIDTH = 8, 
    // Calculates the length of the registerfile 
    // = (2^ADDR_WIDTH)* (DATA_WIDTH-1)
    parameter _REGF_LENGTH = (1 << ADDR_WIDTH)*DATA_WIDTH-1 
)(
    // I2C Interface
    inout top_sda,
    inout top_scl,
    input top_rst,
    // Registerfile
    output reg [_REGF_LENGTH:0] reg_array
);
    // Generate waves files.
	initial
	begin
		$dumpfile ("sim_build/i2c_slave_waves.vcd");
		$dumpvars (0, top);
	end
    // Internal signals to connect i2c-slave and registerfile
    wire [7:0] regf_write_data;
    wire [7:0] regf_read_data;
    wire regf_req;
    wire regf_rw;
    wire regf_ack;

    // Instantiate i2c_slave_controller
    i2c_slave_controller #(
        // Set the address of the I2C slave, 
        // this address need sot be matched in the i2c-protocoll, when adressing the registerfile
        .DEVICE_ADDRESS(7'b0101010)
    )i2c_slave_controller(
        .sda(top_sda),
        .scl(top_scl),
        .rst(top_rst),
        .out_regf_write_data(regf_write_data),
        .regf_read_data(regf_read_data),
        .out_regf_req(regf_req),
        .regf_ack(regf_ack),
        .out_regf_rw(regf_rw)    
    );

    // Instantiate register_file with parameters
    reg_file #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) reg_file (
        .regf_write_data(regf_write_data),
        .out_regf_read_data(regf_read_data),
        .regf_req(regf_req),
        .regf_rw(regf_rw),
        .out_regf_ack(regf_ack),
        .out_reg_array(reg_array)
    );

endmodule