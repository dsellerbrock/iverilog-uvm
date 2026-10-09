module m11_cross_product_over_limit;
  int a, b, c, d;

  covergroup cg;
    ca: coverpoint a { bins values[17] = {[0:16]}; }
    cb: coverpoint b { bins values[17] = {[0:16]}; }
    cc: coverpoint c { bins values[17] = {[0:16]}; }
    cd: coverpoint d { bins values[17] = {[0:16]}; }
    cx: cross ca, cb, cc, cd;
  endgroup

  cg coverage = new;
endmodule
