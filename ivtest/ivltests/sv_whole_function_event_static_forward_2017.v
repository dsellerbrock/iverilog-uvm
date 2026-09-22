module sv_whole_function_event_static_forward;
  class cfg_t;
    static int idx;
    extern function automatic int selector();
  endclass
  cfg_t cfg;
  logic [1:0] data;
  int wakes;
  task automatic waiter; @(data[cfg.selector()]); wakes++; endtask
  initial begin
    cfg = new; cfg_t::idx = 0; data = 2'b10;
    fork waiter(); join_none
    #1; cfg_t::idx = 1;
    #0 if (wakes != 1) $fatal(1, "forward-declared method static read was missed");
    $display("PASS whole-function-static-forward");
    $finish;
  end
  function automatic int cfg_t::selector();
    return idx;
  endfunction
endmodule
