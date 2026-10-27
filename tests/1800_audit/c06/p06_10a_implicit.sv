module sub(input a, output b); assign b = a; endmodule
module p06_10a;
  sub u1(.a(w3), .b(w2));
  assign w3 = 1'b1;
  and g1(w4, w3, w3);
  initial begin #1; $display("IMPL w3=%b w4=%b w2=%b bits=%0d", w3, w4, w2, $bits(w3)); end
endmodule
