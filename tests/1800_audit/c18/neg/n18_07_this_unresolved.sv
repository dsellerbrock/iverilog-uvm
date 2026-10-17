module top;
  class CA; rand int x; endclass CA o;
  initial begin o = new; void'(o.randomize() with { this.nope == 1; }); end
endmodule
