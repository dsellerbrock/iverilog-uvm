module top;
  class K; int m; function int get(); return m; endfunction endclass
  K h; int hit;
  initial begin h = new; @(h.get()); hit = 1; end
  initial begin #5 h.m = 3; #1 $display("%s 9.4.2.nonvirtual_method_event hit=%0d", hit == 1 ? "PASS" : "FAIL", hit); $finish; end
endmodule
