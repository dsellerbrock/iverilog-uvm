class C;
  rand real value;
  real low = 0.5;
  constraint a { value dist {[0.5:1.0] := 1}; }
  constraint b { value dist {[low:1]}; }
  constraint c { value dist {[1:low + 1.0] := 2}; }
`ifdef TEST_2023
  constraint d { value dist {[0.5 +/- 0.1] := 1}; }
`endif
  constraint e { value dist {[low + 1:3] := 1}; }
endclass
module top; C c; initial c = new; endmodule
