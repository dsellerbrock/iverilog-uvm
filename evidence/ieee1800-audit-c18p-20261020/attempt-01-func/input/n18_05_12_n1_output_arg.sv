function automatic int f(bit [9:0] w, output int o);
  o = 0;
  return w[0];
endfunction
class N1;
  rand bit [9:0] v;
  rand int result;
  constraint c { result == f(v, result); }
endclass
module n18_05_12_n1_output_arg;
  N1 n;
  initial begin n = new; void'(n.randomize()); end
endmodule
