package decls;
  virtual class Twin;
  endclass

  class payload #(int N = 0);
    int value;
  endclass

  class Seed #(int N = 97);
    payload#(N) symbolic_only;
    payload#(98) seed_only;
  endclass
endpackage

module top;
  class Twin;
  endclass

  decls::payload#(1) first, repeated;
  decls::payload#(2) second;
  mailbox#(int) builtin_type;

  int value;
  covergroup cg;
    coverpoint value;
  endgroup
endmodule
