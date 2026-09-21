module sv_covergroup_cross_recursive_with_illegal;
  int a, b;
  covergroup cg;
    ca: coverpoint a { bins lo = {0}; bins hi = {1}; }
    cb: coverpoint b { bins lo = {0}; bins hi = {1}; }
    cx: cross ca, cb {
      illegal_bins bad = (binsof(ca) with (ca == 0)) &&
                         (binsof(cb) with (cb == 1));
    }
  endgroup
  cg c = new;
  initial begin
    a = 1; b = 1; c.sample();
    $display("EXPECT_ILLEGAL_BEGIN");
    a = 0; b = 1; c.sample();
    $display("EXPECT_ILLEGAL_END");
    $display("PASSED");
  end
endmodule
