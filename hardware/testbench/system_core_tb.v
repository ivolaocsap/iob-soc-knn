`timescale 1ns / 1ps

`include "iob_lib.vh"
`include "connectfile.vh"

//PHEADER

module knn_tb;

  
  localparam PER=10;
   `CLOCK(clk, PER)
   
   `RESET(rst, 7, 10)

   `SIGNAL(KNN_ENABLE, 1)
   `SIGNAL(KNN_SAMPLE, 1)
   
   `SIGNAL(x0, `DATA_W/2)
   `SIGNAL(x1, `DATA_W/2)
   `SIGNAL(y0, `DATA_W/2)
   `SIGNAL(y1, `DATA_W/2)
   
   `SIGNAL(vizinhancia, `DATA_W*4) 
   `SIGNAL(distancia, `DATA_W)
   
   
   `SIGNAL(out, `DATA_W*4)
  
    
   `SIGNAL_OUT(z, `DATA_W)
   
   /////////////////////////////////////////////
   // TEST PROCEDURE
   //
   initial begin
ifdef VCD
      $dumpfile("knn.vcd");
      $dumpvars();
`endif
      KNN_ENABLE = 0;
      KNN_SAMPLE = 0;

      @(posedge rst);
      @(negedge rst);
      @(posedge clk) #1 KNN_ENABLE = 1;
      @(posedge clk) #1 KNN_SAMPLE = 1;
      @(posedge clk) #1 KNN_SAMPLE = 0;

      //uncomment to fail the test 
      //@(posedge clk) #1;
      
      @(posedge clk) #1 
       //en=1; 
      x0=3; 
      x1=9;
      y0=12; 
      y1=3;
      #1
      //z=KNN_VALUE;
      $display ("x0: %d  x1: %d  y0: %d  y1: %d Distancia %d",x0, x1, y0, y1,z);

      if( z == 117) 
        $display("Test passed");
      else
        $display("Test failed: 117 not equal to %d", z);
   
      @(posedge clk) #1
      
      vizinhancia[`DATA_W-1:0] = 32'b00000000000000000000000000000001;
      vizinhancia[2*`DATA_W-1:`DATA_W] =32'b00000000000000000000000000000010;
      neighbour[3*`DATA_W-1:2*`DATA_W] =32'b00000000000000000000000000000100;
      neighbour[4*`DATA_W-1:3*`DATA_W] =32'b00000000000000000000000000001000;
      distancia =32'b00000000000000000000000000000011;
   
      #1
      if(out[`DATA_W-1:0] == 1) 
        $display("Test passed");
      else
        $display("Test failed: expecting knn value 1 but got %d", out[`DATA_W-1:0]);
        
       if(out[2*`DATA_W-1:`DATA_W] == 2) 
        $display("Test passed");
      else
        $display("Test failed: expecting knn value 2 but got %d", out[2*`DATA_W-1:`DATA_W]);
        
       if(out[3*`DATA_W-1:2*`DATA_W] == 3) 
        $display("Test passed");
      else
        $display("Test failed: expecting knn value 3 but got %d", out[3*`DATA_W-1:2*`DATA_W]);
      
      if(out[4*`DATA_W-1:3*`DATA_W] == 4) 
        $display("Test passed");
      else
        $display("Test failed: expecting knn value 4 but got %d", outa[4*`DATA_W-1:3*`DATA_W]);
      
     
     $display("Tests failed "); 
      
      $finish;
   end
   
 
   //instantiate knn core
  knn_core knn0
     (
      .KNN_ENABLE(KNN_ENABLE),
      .clk(clk),
      .rst(rst),
      .x0(x0),
      .x1(x1),
      .y0(y0),
      .y1(y1),
      .z(z)
      );
   
    knn_list list0
    (
     .neighbour_data(vizinhancia),
     .clk(clk),
     .rst(rst),
     .dist_target(distancia),
     .list_out(out)
	);


endmodule

