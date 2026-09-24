// IEEE 1800-2017 7.4.6 / 2023 7.4.5: an indexed slice width must be
// positive and constant, while its base must be integral. Slice element
// state representations must be equivalent.
module test;
  logic data[];
  logic selected[];
  bit incompatible[];
  int variable_width;
  real nonintegral_base;

  initial begin
    data = new[8];
    selected = data[0 +: variable_width];
    selected = data[0 +: 0];
    selected = data[nonintegral_base +: 2];
    data[0 +: variable_width] = selected;
    data[nonintegral_base +: 2] = selected;
    data[0 +: 2] = incompatible;
  end
endmodule
