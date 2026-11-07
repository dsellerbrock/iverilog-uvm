`timescale 1ns/1ns
module issue2700_buf(input a, output y);
  assign y = a;
  specify (a => y) = 1; endspecify
endmodule

module issue2700_negpulse;
  reg a = 0;
  wire y;
  issue2700_buf u(a, y);

  initial begin
    $sdf_annotate("ivltests/issue2700_negpulse.sdf", issue2700_negpulse);
    #10 a = 1;
    #1 a = 0;
    #5;
    if (y !== 1'b0)
      $fatal(1, "negative pulse was not cancelled: y=%b", y);
    $display("negative pulse cancelled");
    $finish;
  end
endmodule
