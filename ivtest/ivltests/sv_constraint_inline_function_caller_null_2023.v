class cfg_t;
  function int method(); return 6; endfunction
endclass
class packet;
  rand int n = 99;
  int posts;
  function void post_randomize(); posts++; endfunction
endclass
module caller_null_2023;
  task automatic check_null();
    cfg_t cfg;
    packet req = new();
    if (req.randomize() with { n == cfg.method(); }) $fatal(1, "null caller unexpectedly solved");
    if (req.n != 99 || req.posts != 0) $fatal(1, "null caller changed state");
  endtask
  initial begin check_null(); $display("PASS caller_null_2023"); end
endmodule
