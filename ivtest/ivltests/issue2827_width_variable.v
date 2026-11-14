`timescale 1ns/1ns
module issue2827_width_variable; reg c = 0;
  specify $width(posedge c, 5); endspecify

  initial begin
    #10 c = 1;
    #2 c = 0;
    #10 $finish;
  end
endmodule
