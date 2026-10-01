class i2c_event_repro;
  event fired;
  task trigger(); -> fired; endtask
  task wait_trigger(); @fired; endtask
endclass

class i2c_monitor_repro;
  i2c_event_repro start, stop;
  bit saw_start, saw_stop;
  function new(); start = new; stop = new; endfunction
  task automatic perf_monitor(
`ifdef REF_HANDLES
    ref i2c_event_repro start_arg, ref i2c_event_repro stop_arg
`else
    input i2c_event_repro start_arg, input i2c_event_repro stop_arg
`endif
  );
    start_arg.wait_trigger();
    saw_start = 1;
    fork
      begin stop_arg.wait_trigger(); saw_stop = 1; end
      begin #10; end
    join_any
    disable fork;
  endtask
  task run();
    fork
      perf_monitor(start, stop);
      begin #1; start.trigger(); #1; stop.trigger(); end
    join
  endtask
endclass

module i2c_event_handle_input_repro;
  i2c_monitor_repro monitor;
  initial begin
    monitor = new;
    monitor.run();
    if (!monitor.saw_start || !monitor.saw_stop) $fatal(1, "event handle lost");
    $display("PASS event handles");
  end
endmodule
