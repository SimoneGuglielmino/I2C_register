/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
module TT_top (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
  // Generate waves files.
  initial
  begin
    $dumpfile("sim_build/waves.vcd");
    $dumpvars (0, TT_top);
  end
  parameter DEVICE_ADDR = 7'b0101010;
  parameter DATA_WIDTH = 8;
  parameter ADDR_WIDTH = 4;
  // I2C interface
  wire top_sda;
  wire top_scl;
  wire top_rst;
  wire top_write_enable;
  // If write_enable = 1 sda -> output, else sda -> input
  assign top_sda =(top_write_enable == 1) ? 1'bz : uio_in[0];
  assign uio_out[0] = top_sda;
  assign uio_oe[0] = top_write_enable;
  assign top_scl = clk;
  // Internal signals to connect i2c-slave and registerfile
  wire [7:0] regf_write_data;
  wire [7:0] regf_read_data;
  wire [7:0] out_reg_array;
  wire regf_req;
  wire regf_rw;
  wire regf_ack;

  assign uo_out = out_reg_array;
  // List all unused inputs to prevent warnings
  wire _unused = &{ena, 1'b0};

  // Instantiate i2c_slave_controller
  i2c_slave_controller #(
      // Set the address of the I2C slave, 
      // this address need sot be matched in the i2c-protocoll, when adressing the registerfile
      .DEVICE_ADDRESS(DEVICE_ADDR)
  )i2c_slave_controller(
      .sda(top_sda),
      .scl(top_scl),
      .out_write_enable(top_write_enable),
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
      .out_reg_array(out_reg_array)
  );

endmodule
