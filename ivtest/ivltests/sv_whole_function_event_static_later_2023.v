module sv_whole_function_event_static_later;
  class cfg_t;
    static int idx;
    function automatic int unrelated(); return 0; endfunction
    // Deliberately later than the class member declaration and unrelated method.
    function automatic int selector(); return idx; endfunction
  endclass
  cfg_t cfg;
  logic [1:0] data;
  int wakes;
  task automatic waiter; @(data[cfg.selector()]); wakes++; endtask
  initial begin
    cfg = new; cfg_t::idx = 0; data = 2'b10;
    fork waiter(); join_none
    #1; cfg_t::idx = 1;
    #0 if (wakes != 1) $fatal(1, "later method static read was missed");
    $display("PASS whole-function-static-later");
    $finish;
  end
endmodule
