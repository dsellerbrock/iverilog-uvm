module top; int da[]; int hit;
  initial begin @(da.size() > 0); hit = 1; end
  initial begin #5 da = new[2]; #1 $display("%s 9.4.2.size_gt0_event hit=%0d", hit == 1 ? "PASS" : "FAIL", hit); $finish; end
endmodule
