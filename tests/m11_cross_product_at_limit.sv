module m11_cross_product_at_limit;
  int a, b, c, d;

  covergroup cg;
    ca: coverpoint a { bins values[16] = {[0:15]}; }
    cb: coverpoint b { bins values[16] = {[0:15]}; }
    cc: coverpoint c { bins values[16] = {[0:15]}; }
    cd: coverpoint d { bins values[16] = {[0:15]}; }
    cx: cross ca, cb, cc, cd;
  endgroup

  cg coverage = new;
endmodule
