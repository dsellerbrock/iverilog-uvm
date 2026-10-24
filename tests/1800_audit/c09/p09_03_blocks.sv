module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  logic [7:0] r; int areg, breg, creg, v, m_seen; time t0; string str; event Aevent, Bevent;
  initial begin : ini
    breg = 5; begin areg = breg; creg = areg; end chk("9.3.1.sequential_order", creg == 5);
    t0 = $time; begin #10 r = 'h35; #10 r = 'hE2; end
    chk("9.3.1.relative_delays_total", ($time - t0) == 20 && r == 'hE2);
    t0 = $time; fork #50 r = 'h35; #100 r = 'hE2; #150 r = 'h00; #200 r = 'hF7; join
    chk("9.3.2.fork_join_waits_for_all", ($time - t0) == 200 && r == 'hF7);
    fork #50 r = 'h35; #100 r = 'hE2; #150 r = 'h00; #200 r = 'hF7; join_none
    #60  chk("9.3.2.waveform_t50", r == 'h35);
    #50  chk("9.3.2.waveform_t100", r == 'hE2);
    #50  chk("9.3.2.waveform_t150", r == 'h00);
    #50  chk("9.3.2.waveform_t200", r == 'hF7);
    t0 = $time; fork #10; #30; join_any
    chk("9.3.2.join_any_resumes_at_first", ($time - t0) == 10); #25;
    v = 0; fork v = 1; join_none
    chk("9.3.2.join_none_spawned_not_started", v == 0);
    #1 chk("9.3.2.join_none_runs_after_parent_blocks", v == 1);
    str = "";
    for (int j = 1; j <= 3; ++j)
      fork
        automatic int k = j;
        #k str = {str, $sformatf("%0d", k)};
        begin automatic int m = j; m_seen = m; end
      join_none
    #5 chk("9.3.2.block_item_init_per_iteration_123", str == "123");
    $display("INFO 9.3.2.m_seen=%0d (2023 requires 4; 2017 undetermined)", m_seen);
    breg = 9; areg = 0; t0 = $time;
    fork begin #3 ->Bevent; #3 ->Aevent; end join_none
    begin fork @Aevent; @Bevent; join areg = breg; end
    chk("9.3.3.join_of_events_either_order", areg == 9 && ($time - t0) == 6);
    areg = 0; t0 = $time;
    fork begin #2 ->Aevent; ->Bevent; end join_none
    begin fork @Aevent; @Bevent; join areg = breg; end
    chk("9.3.3.join_of_events_same_time", areg == 9 && ($time - t0) == 2);
    begin : blkA int x; x = 7; end
    chk("9.3.4.hier_ref_into_named_block", top.ini.blkA.x == 7);
    repeat (3) begin : cnt int s; s = s + 1; end
    chk("9.3.4.block_variables_static", top.ini.cnt.s == 3);
    begin : b1 end : b1
    fork : f1 join : f1
    fork : f2 #1; join_any : f2
    fork : f3 join_none : f3
    chk("9.3.4.matching_end_names_accepted", 1);
    $display("DONE fails=%0d", fails);
  end
endmodule
