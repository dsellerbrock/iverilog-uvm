module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  int rega, regb, regc, x, y, a, cntw, iters, brk, q, act;
  event retrig, ev1, trig, reset;
  task tw; begin #10 cntw++; end endtask
  task proc_a; begin if (a == 0) disable proc_a; y = 1; end endtask
  always begin : monostable #25 q = 0; end
  always @retrig begin disable monostable; q = 1; end
  initial begin #100 ->ev1; #1 ->trig; #1 ->reset; end
  initial begin : main
    regb = 3;
    begin : block_name rega = regb; disable block_name; regc = 1; end
    chk("9.6.2.self_disable_skips_rest", rega == 3 && regc == 0);
    begin : b2 if (a == 0) disable b2; x = 5; end
    chk("9.6.2.forward_goto_style", x == 0);
    a = 0; proc_a(); chk("9.6.2.disable_task_from_inside", y == 0);
    a = 1; proc_a(); chk("9.6.2.task_continues_when_not_disabled", y == 1);
    begin : outer_block
      for (int i = 0; i < 5; i++) begin : inner_block
        if (i == 1) disable inner_block;
        iters++;
        if (i == 3) disable outer_block;
        brk++;
      end
    end
    chk("9.6.2.disable_acts_as_continue_and_break", iters == 3 && brk == 2);
    disable block_name; chk("9.6.2.disable_idle_block_is_noop", 1);
    fork tw; #1 tw; #2 disable tw; join
    #20 chk("9.6.2.disable_task_all_activations", cntw == 0);
    fork
      begin : event_expr @ev1; repeat (3) @trig; #4 act++; end
      @reset disable event_expr;
    join
    chk("9.6.2.disable_in_fork_terminates_join", act == 0 && $time == 102);
    #200 ->retrig; #1 chk("9.6.2.monostable_set", q == 1);
    #19 ->retrig;
    #20 chk("9.6.2.monostable_retrigger_extends", q == 1);
    #10 chk("9.6.2.monostable_expires", q == 0);
    $display("DONE fails=%0d", fails);
    $finish;
  end
endmodule
