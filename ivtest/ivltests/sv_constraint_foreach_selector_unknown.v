// IEEE 1800-2017 18.5.8.1 / 2023 18.5.7.1: the prefix is an existing value.
class selected_unknown;
  rand int a[2][3];
  constraint c { foreach (a[missing][j]) a[0][j] == j; }
endclass
module main;
  selected_unknown obj;
  initial begin obj = new; if (!obj.randomize()) $fatal(1, "randomize"); end
endmodule
