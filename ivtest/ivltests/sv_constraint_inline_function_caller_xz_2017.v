class cfg_t;
  logic [7:0] value;
  function logic [7:0] method(); return value; endfunction
endclass
class packet;
  rand logic [7:0] n = 8'h63;
  int posts;
  function void post_randomize(); posts++; endfunction
endclass
module caller_xz_2017;
  initial begin
    cfg_t cfg;
    packet req;
    cfg = new();
    req = new();
    cfg.value = 8'hx;
    if (req.randomize() with { n == cfg.method(); }) $fatal(1, "X caller unexpectedly solved");
    if (req.n !== 8'h63 || req.posts != 0) $fatal(1, "X caller changed state");
    cfg.value = 8'hz;
    if (req.randomize() with { n == cfg.method(); }) $fatal(1, "Z caller unexpectedly solved");
    if (req.n !== 8'h63 || req.posts != 0) $fatal(1, "Z caller changed state");
    $display("PASS caller_xz_2017");
  end
endmodule
