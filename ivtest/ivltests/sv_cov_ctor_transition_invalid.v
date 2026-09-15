module test;
  covergroup cg(logic [3:0] lo, logic [3:0] hi) with function sample(logic [3:0] value);
    cp: coverpoint value { bins path[] = (lo => hi); }
  endgroup
  cg c;
  initial begin c = new(4'bx, 1); c.sample(0); #0; $fatal(1,"invalid endpoint accepted"); end
endmodule
