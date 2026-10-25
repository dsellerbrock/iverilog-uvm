module top; real AOR[]; int hit;
  initial begin @(AOR.size()); hit = 1; end
  initial begin #5 AOR = new[3]; #1 $display("%s 9.4.2.darray_real_size_event hit=%0d", hit == 1 ? "PASS" : "FAIL", hit); $finish; end
endmodule
