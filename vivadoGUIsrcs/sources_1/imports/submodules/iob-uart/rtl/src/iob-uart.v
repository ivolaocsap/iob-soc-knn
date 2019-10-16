`timescale 1ns/1ps
`include "iob-uart.vh"

module iob_uart (
                 //cpu interface 
	         input             clk,
	         input             rst,

                 input [2:0]       address,
	         input             sel,
                 input             read,
                 input             write,

	         input [31:0]      data_in,
	         output reg [31:0] data_out,

                 //serial i/f
	         output            ser_tx,
	         input             ser_rx
                   );

   // internal registers
   wire                              tx_wait;
   reg [31:0]                        cfg_divider;

   // receiver
   reg [3:0]                         recv_state;
   reg [31:0]                        recv_divcnt;
   reg [7:0]                         recv_pattern;
   reg [7:0]                         recv_buf_data;
   reg                               recv_buf_valid;
 
   // sender
   reg [9:0]                         send_pattern;
   reg [3:0]                         send_bitcnt;
   reg [15:0]                        send_divcnt;
   `ifdef SIM
   reg                               prchar;
   `endif
   
   // register access
   reg                               data_write_en;
   reg                               data_read_en;
   reg                               div_write_en;

   // reset
   wire                              rst_int;
   reg                               rst_soft;

   //reset hard and soft
   assign rst_int = rst | rst_soft;


   
   ////////////////////////////////////////////////////////
   // Address decoder
   ////////////////////////////////////////////////////////

   // write
   always @* begin
      data_write_en = 1'b0;
      div_write_en = 1'b0;
      rst_soft = 1'b0;
      if(sel & write)
        case (address)
          `UART_DIV: div_write_en = 1'b1;
          `UART_DATA: data_write_en = 1'b1;
          `UART_SOFT_RESET: rst_soft = 1'b1;
          default:;
        endcase
   end // always @ *

   //read
   always @*
     if(sel & read) begin
       case (address)
         `UART_WRITE_WAIT: data_out = {31'd0, tx_wait};
         `UART_DIV       : data_out = cfg_divider;
         `UART_DATA      : begin 
            data_out = recv_buf_data;
            data_read_en = 1'b1;
         end
         `UART_READ_VALID: data_out = {31'd0,recv_buf_valid};
         default         : begin 
            data_out = ~0;
            data_read_en = 1'b0;
         end
       endcase
     end else begin 
        data_read_en = 1'b0;
        data_out = ~0;
     end


       
   // internal registers
   assign tx_wait = (send_bitcnt != 4'd0);

   // division factor
   always @(posedge clk)
     if (rst_int)
       cfg_divider <= 1;
     else if (div_write_en)
       cfg_divider <= data_in;

   ////////////////////////////////////////////////////////
   // Serial RX
   ////////////////////////////////////////////////////////

   always @(posedge clk, posedge rst_int) begin
      if (rst_int)
	begin
           recv_state <= 0;
           recv_divcnt <= 0;
           recv_pattern <= 0;
           recv_buf_data <= 0;
           recv_buf_valid <= 0;
	end
      else
	begin
           recv_divcnt <= recv_divcnt + 1;
           if (data_read_en)
             recv_buf_valid <= 0;

           case (recv_state)
             
             // Detect start bit (i.e., when RX line goes to low)
             4'd0:
               begin
                  if (!ser_rx)
                    recv_state <= 1;
                  recv_divcnt <= 1;
               end
             
             // Forward in time to the middle of the start bit
             4'd1:
               if ( (2*recv_divcnt) >= cfg_divider)
                 begin
                    recv_state <= 2;
                    recv_divcnt <= 1;
                 end
             
             // Sample the 8 bits from the RX line and put them in the shift register
             default: // states 4'd2 through 4'd9
               if (recv_divcnt >= cfg_divider)
                 begin
                    recv_pattern <= {ser_rx, recv_pattern[7:1]};
                    recv_state <= recv_state + 1'b1;
                    recv_divcnt <= 1;
                 end
             
             // Put the received byte in the output data register; drive read valid to high
             4'd10:
               if (recv_divcnt >= cfg_divider)
                 begin
                    recv_buf_data <= recv_pattern;
                    recv_buf_valid <= 1;
                    recv_state <= 0;
                 end
             
           endcase // case (recv_state)
	end // else: !if(rst_int)
   end //always @
	 
   ////////////////////////////////////////////////////////
   // Serial TX
   ////////////////////////////////////////////////////////
   
   //div counter
   always @(posedge clk, posedge rst_int)
     if(rst_int) //reset
       send_divcnt <= 16'd0;
     else if(data_write_en) //set
       send_divcnt <= 16'd1;
     else if(send_divcnt == cfg_divider) //wrap around
       send_divcnt <= 16'd1;             
     else if(send_divcnt != 16'd0) //increment
       send_divcnt <= send_divcnt + 1'b1;

   //send bit counter
   always @(posedge clk, posedge rst_int)
     if (rst_int) //reset
       send_bitcnt <= 4'd0;
     else if (data_write_en) //load 
       send_bitcnt <= 4'd10;
     else if (send_bitcnt != 0 && send_divcnt == cfg_divider) //decrement
       send_bitcnt <= send_bitcnt - 1'b1;

   // shift register
   always @(posedge clk, posedge rst_int)
      if (rst_int) //reset
        begin
           send_pattern <= ~10'b0;
           `ifdef SIM
           prchar <= 1'b0;
           `endif
        end
      else if (data_write_en) 
        //load
        begin
           send_pattern <= {1'b1, data_in[7:0], 1'b0};
           `ifdef SIM
           prchar <= ~prchar;
           if(prchar) $write("%c", data_in[7:0]);
           `endif
        end
      else if (send_bitcnt && send_divcnt == cfg_divider) 
        //shift right
        send_pattern <= {1'b1, send_pattern[9:1]};

   // send serial comm
   assign ser_tx = send_pattern[0];

endmodule
