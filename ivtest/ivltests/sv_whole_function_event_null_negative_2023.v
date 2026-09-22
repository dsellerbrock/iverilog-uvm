// Expected runtime error: evaluating a method on a null receiver must fail cleanly, not assert or crash.
module sv_whole_function_event_null_negative;
  class cfg_t;
    function automatic int selector(); return 0; endfunction
  endclass
  cfg_t cfg;
  logic [1:0] data;
  initial begin
    cfg = null;
    @(data[cfg.selector()]);
    $fatal(1, "null receiver event unexpectedly continued");
  end
endmodule
