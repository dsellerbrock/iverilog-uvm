`timescale 1ns/1ns
module p32_src(input a, output y);
  assign y = a;
endmodule

module p32_dst(input a, output y);
  assign y = a;
endmodule

module p32_ic;
  reg a = 0;
  wire link, y;
  p32_src u1(.a(a), .y(link));
  p32_dst u2(.a(link), .y(y));
  always @(y) if ($time > 0) $display("Y %0t %b", $time, y);
  initial begin
    $sdf_annotate("p32_ic.sdf", p32_ic);
    #10 a = 1;
    #10 $finish;
  end
endmodule
