class C;
  rand int value;
  constraint a { value dist {[1:3] := 1, [4:5], [6:7] :/ 1}; }
`ifdef TEST_2023
  rand real r;
  constraint b { r dist {[0.5:1.0] :/ 1, 2.0 := 1, [1:3] := 2}; }
  constraint c { r dist {[0.5 +/- 0.1] :/ 1, [3 +/- 1] := 1}; }
`endif
endclass
module top; C c; initial begin c = new; $display("PASS"); end endmodule
