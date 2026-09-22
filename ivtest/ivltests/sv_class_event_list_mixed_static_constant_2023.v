module core_mixed_static_constant;
  class state_t; logic member; endclass
  class wrapper_t;
    state_t cfg;
    function new; cfg = new; endfunction
  endclass
  wrapper_t w;
  logic [2:0] ordinary;
  int wakes;
  task automatic wait_one;
    @(w.cfg.member, ordinary, 1'b0);
    wakes++;
  endtask
  initial begin
    w = new;
    fork wait_one(); join_none
    #1 ordinary = 3'b101;
    #1 if (wakes != 1) $fatal(1, "ordinary leaf missed");
    fork wait_one(); join_none
    #1 ordinary = 3'b101;
    #1 if (wakes != 1) $fatal(1, "equal ordinary value woke");
    w.cfg.member = 1'b1;
    #1 if (wakes != 2) $fatal(1, "class leaf missed after equal ordinary value");
    fork wait_one(); join_none
    #1 w.cfg.member = 1'b1;
    #1 if (wakes != 2) $fatal(1, "equal class value woke");
    ordinary = 3'b010;
    #1 if (wakes != 3) $fatal(1, "ordinary rearm missed");
    $display("PASS core mixed static constant"); $finish;
  end
endmodule
