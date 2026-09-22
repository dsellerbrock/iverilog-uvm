// Deliberately uses the no-parentheses zero-argument method grammar.
module sv_whole_function_event_no_parens_static;
  class cfg_t;
    static logic value;
    extern function automatic logic selected;
  endclass
  cfg_t cfg;
  int wakes;
  task automatic waiter;
    @(cfg.selected);
    wakes++;
  endtask
  initial begin
    cfg = new; cfg_t::value = 0;
    fork waiter(); join_none
    #1; cfg_t::value = 1;
    #0 if (wakes != 1) $fatal(1, "no-parentheses later method static read was missed");
    $display("PASS whole-function-no-parens-static");
    $finish;
  end
  function automatic logic cfg_t::selected;
    return value;
  endfunction
endmodule
