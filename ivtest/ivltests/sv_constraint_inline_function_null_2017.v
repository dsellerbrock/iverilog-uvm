class cfg;
  function int value(); return 6; endfunction
endclass
class packet;
  rand int n = 99;
  int posts;
  cfg source;
  constraint class_control { n inside {[0:100]}; }
  function void post_randomize(); posts++; endfunction
endclass
module null_target_preserve;
  packet req = new();
  initial begin
    if (req.randomize() with { n == source.value(); }) $fatal(1, "null target unexpectedly solved");
    if (req.n != 99 || req.posts != 0) $fatal(1, "null target changed state: n=%0d posts=%0d", req.n, req.posts);
    $display("PASS null_target_preserve n=%0d", req.n);
  end
endmodule
