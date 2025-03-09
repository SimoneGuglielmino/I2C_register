/*  This design is a asynchronous i2c interface used to access a registerfile.
  Parts of this design have been taken from https://dlbeer.co.nz/articles/i2c.html

  In this a design a generic i2c interface and a interface to a registerfile is combined.

  The desgin uses the start and stop detecors from https://dlbeer.co.nz/articles/i2c.html.
  Using these the i2c protocoll signals START,STOP and RESTART can be detected.

  The start and stop detectos produce a respective START and STOP signal when detecting the START/STOP conditions from I2C.
  The conditions are:
    START:  negative edge on SDA, while SCL is high
    STOP: positive edge on SDA, while SCL is high

  Additionally to the i2c interface signals this design has a RST signal, [TODO try if the reset can be universal async]

  The state machine controlling the interface has 7 states:
    IDLE        : Wating for a request
    READ_ADDR     : Reading the I2C Device Address
    SEND_ADDR_ACK   : Send Ack over SDA
    READ_DATA     : Reading input data
    WRITE_DATA      : Writing data on I2C IF over SDA
    SEND_READ_DATA_ACK  : Send Ack over SDA
    GET_WRITE_ACK   : Recieve Ack over SDA

  The steps for the i2c protocol are as follows:
    1. Send the 7bit I2C device address and the read/write bit
    2. Send/recieve 8bits of data on SDA

  The implementation of this design does not support restarts after data has been send.
  It is therefore only possible to send 1byte at a time. After 1 byte of data the address has to be resend.

  The state machine is clocked on the negative edge of SCL and the start and stop detectors are clocked on the edges of
  SDA, ommiting the need for a internal clock, but making the design vunerable to glitches on the i2c signals. */
module i2c_slave_controller #(
  parameter DEVICE_ADDRESS = 7'b0101010 //  Standard value for device address
)(
  // General If
  input rst,

  // I2C Interface
  input sda_in,
  input scl,
  output sda_out,
  output out_write_enable,
  // Register File Interface
  output wire[7:0] out_regf_write_data,
  output wire out_regf_req,
  output wire out_regf_rw,
  input [7:0] regf_read_data,
  // MISC outputs to have them available
  output out_start,
  output out_stop,
  output out_start_reset,
  output out_stop_reset
  );

  // States
  localparam IDLE       = 0; // Wating for a request
  localparam READ_ADDR    = 1; // Reading the I2C Device Address
  localparam SEND_ADDR_ACK  = 2; // Send I2C Ack over SDA
  localparam READ_DATA    = 3; // Reading I2C input data
  localparam WRITE_DATA     = 4; // Writing data on I2C IF over SDA
  localparam SEND_READ_ACK  = 5; // Send I2C Ack over SDA
  localparam GET_WRITE_ACK  = 6; // Recieve I2C Ack over SDA

  // Register File Interface Drivers
  reg[7:0] regf_data_in;
  reg regf_req;
  reg regf_rw;
  assign out_regf_write_data = regf_data_in;
  assign out_regf_req = regf_req;
  assign out_regf_rw = regf_rw;

  // I2C Interface Drivers
  reg reg_sda_out;
  assign sda_out = reg_sda_out;
  reg write_enable = 0;
  assign out_write_enable = write_enable;
  reg ack_recieved = 0;

  // State Machine Variables
  reg [7:0] addr;
  reg [2:0] counter;
  reg [7:0] state = 0;

  /* The design of the start and stop detectors are taken from https://dlbeer.co.nz/articles/i2c.html */
  // Start detector
  reg   start;
  reg     start_resetter;
  wire    start_rst = !rst | start_resetter;

  assign out_start = start;
  assign out_start_reset = start_rst;

  always @ (posedge start_rst or negedge sda_in)
  begin
    if (start_rst)
      start <= 1'b0;
    else
      start <= scl;
  end

  always @ (negedge rst or posedge scl)
  begin
    if (!rst)
      start_resetter <= 1'b0;
    else
      start_resetter <= start;
  end

  // Stop detector
  reg     stop;
  reg   stop_resetter;
  wire  stop_rst = !rst | stop_resetter;

  assign out_stop = stop;
  assign out_stop_reset = stop_rst;

  always @ (posedge stop_rst or posedge sda_in)
  begin
    if (stop_rst)
      stop <= 1'b0;
    else
      stop <= scl;
  end

  always @ (negedge rst or posedge scl)
  begin
    if (!rst)
      stop_resetter <= 1'b0;
    else
      stop_resetter <= stop;
  end

  // I2C Driver
  // Process to drive the sda line when the slave accesses the sda line
  always @(negedge rst or posedge scl) begin
    if (!rst) begin
      ack_recieved <= 0;
      addr <= 0;
      regf_data_in <= 0;
      regf_req <= 0;
    end else begin
      case(state)
        IDLE: begin
          ack_recieved <= 0;
          regf_req <= 0;
        end
        READ_ADDR: begin
          addr[counter] <= sda_in;
          regf_req <= 0;
        end
        SEND_ADDR_ACK: begin
          if (addr[0] == 1) begin
            regf_req <= 1;
          end else begin
            regf_req <= 0;
          end
        end
        READ_DATA: begin
          regf_data_in[counter] <= sda_in;
        end
        WRITE_DATA: begin
          regf_req <= 0;
        end
        SEND_READ_ACK: begin
          regf_req <= 1;
        end
        GET_WRITE_ACK: begin
          if (sda_in == 0) begin
            ack_recieved <= 1;
          end
        end
      endcase
    end
  end

  // Main IF State Machine
  always @(negedge rst or negedge scl)
  begin
    if (!rst)
    begin
      // Reset Signals on RST
      state <= IDLE;
      counter <= 0;
      write_enable <= 0;
      regf_rw <= 0;
      reg_sda_out <= 0;
    end else begin

      begin
        case(state)
          IDLE: begin
            if (start == 1) begin
              state <= READ_ADDR;
              counter <= 7;
            end
            write_enable <= 0;
          end

          READ_ADDR: begin
            write_enable <= 0;
            if (counter == 0) begin
              // Send the acknowledge
              reg_sda_out <= 0;
              write_enable <= 1;
              // Check the address and answer only if device is addressed
              if(addr[7:1] == DEVICE_ADDRESS) begin
                counter <= 7;
                state <= SEND_ADDR_ACK;
                if(addr[0] == 1) begin
                // Hand the request to regf if read
                regf_rw <= 1;
                end
              end else begin
                // If not device addess do nothing
                state <= IDLE;
              end
            end else begin
              counter <= counter - 1;
            end
          end

          SEND_ADDR_ACK: begin
            if(addr[0] == 0) begin
              // Access is read so we need to free the SDA
              write_enable <= 0;
              state <= READ_DATA;
            end else begin
              // Access is write to we need to keep the SDA
              write_enable <= 1;
              state <= WRITE_DATA;
              // set the first bit
              reg_sda_out <= regf_read_data[counter];
              counter <= counter - 1;
            end
          end

          READ_DATA: begin
            write_enable <= 0;
            if(counter == 0) begin
              // Send ACK over SDA
              reg_sda_out <= 0;
              write_enable <= 1;
              // Setup regf access
              regf_rw <= 0;
              // Change States
              state <= SEND_READ_ACK;
            end else counter <= counter - 1;
          end

          WRITE_DATA: begin
            write_enable <= 1;
            reg_sda_out <= regf_read_data[counter];
            if(counter == 0) begin
              // Here we could wait for the I2C Ack
              //Change State
              state <= GET_WRITE_ACK;
            end else counter <= counter - 1;
          end
          SEND_READ_ACK: begin
            write_enable <= 0;
            state <= IDLE;
          end
          GET_WRITE_ACK: begin
            write_enable <= 0;
            if (ack_recieved == 1) begin
              state <= IDLE;
            end
          end
        endcase
      end
    end
  end
endmodule
