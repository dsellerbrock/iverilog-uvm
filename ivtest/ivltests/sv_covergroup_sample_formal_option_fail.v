// IEEE 1800-2017/2023 19.8.1 prohibits sample() formals in option expressions.
module top;
  bit a;
  covergroup cg with function sample(int x);
    option.weight = x;
    cp: coverpoint a;
  endgroup
endmodule
