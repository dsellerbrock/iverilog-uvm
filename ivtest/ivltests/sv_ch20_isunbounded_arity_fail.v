// IEEE 1800-2017 20.6: $isunbounded takes exactly one argument.
module test;
  int value;
  initial begin
    value = $isunbounded();
    value = $isunbounded(1, 2);
  end
endmodule
