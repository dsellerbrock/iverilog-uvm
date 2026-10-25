function automatic int f(ref bit [9:0] w);
  return w[0];
endfunction
class N2;
  rand bit [9:0] v;
  rand int result;
  constraint c { result == f(v); }
endclass
module n18_05_12_n2_ref_arg;
  N2 n;
  initial begin n = new; void'(n.randomize()); end
endmodule
