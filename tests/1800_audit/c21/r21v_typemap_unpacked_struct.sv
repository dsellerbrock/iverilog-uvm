module top;
 typedef struct {int x; logic [1:0] y;} us_t;
 us_t vu;
 initial begin
  $dumpfile("typemap-unpacked.vcd"); $dumpvars(0,top);
  #1 vu.x=3; vu.y=2'b10; $display("%0d %0d",vu.x,vu.y); #1 $finish;
 end
endmodule
