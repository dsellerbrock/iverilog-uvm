checker procedural_reader(logic x);
  initial $display("procedural reader: %b", x);
endchecker

checker continuous_reader(logic x);
  logic stored;
  assign stored = x;
endchecker

module top;
  logic a = 1'b1;
  procedural_reader procedural_control(a);
  continuous_reader continuous_control(a);
  procedural_reader bad_procedural(const'(a));
  continuous_reader bad_continuous((const'(a) & 1'b1));
endmodule
