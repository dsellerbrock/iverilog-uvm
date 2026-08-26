// IEEE 1800-2023 6.21, 13.3.1, and 25.9: a static interface method may
// contain explicitly automatic declarations, and a call through a virtual
// interface must allocate the same per-call storage as a direct call.
interface vif_mixed_lifetime_if;
  int task_observed [1:2];
  int function_observed [3:4];

  task static overlap(input int id);
    automatic int captured = id;
    automatic int payload[];

    payload = new[2];
    payload[0] = captured;
    payload[1] = captured + 10;
    if (captured == 1) begin
      #10;
    end else begin
      #1;
    end

    // id is an inherited static formal, so the second invocation's value is
    // deliberately shared. captured/payload remain per invocation.
    task_observed[captured] = payload[0] * 100 + payload[1] * 10 + id;
  endtask

  function static void record(input int id);
    automatic int captured = id;
    automatic int payload[];

    payload = new[1];
    payload[0] = captured + 20;
    function_observed[captured] = captured * 100 + payload[0] * 10 + id;
  endfunction
endinterface

class vif_mixed_lifetime_runner;
  virtual vif_mixed_lifetime_if vif;

  task call_overlap(int id);
    vif.overlap(id);
  endtask

  task call_record(int id);
    vif.record(id);
  endtask
endclass

module sv_vif_mixed_lifetime_call_frame;
  vif_mixed_lifetime_if if0();
  vif_mixed_lifetime_if if1();
  vif_mixed_lifetime_runner runner;
  int errors;

  initial begin
    runner = new;
    runner.vif = if0;

    fork
      runner.call_overlap(1);
      begin
        #1;
        runner.call_overlap(2);
      end
    join
    runner.call_record(3);
    runner.call_record(4);

    if (if0.task_observed[1] !== 212 || if0.task_observed[2] !== 322
        || if0.function_observed[3] !== 533
        || if0.function_observed[4] !== 644) begin
      $display("FAILED if0 task=%0d,%0d function=%0d,%0d",
               if0.task_observed[1], if0.task_observed[2],
               if0.function_observed[3], if0.function_observed[4]);
      errors++;
    end

    // Rebinding the same virtual-interface handle must select the other
    // instance and its independent mixed-lifetime method frames.
    runner.vif = if1;
    runner.call_overlap(2);
    runner.call_record(3);
    if (if1.task_observed[2] !== 322
        || if1.function_observed[3] !== 533
        || if1.task_observed[1] !== 0
        || if1.function_observed[4] !== 0) begin
      $display("FAILED if1 task=%0d,%0d function=%0d,%0d",
               if1.task_observed[1], if1.task_observed[2],
               if1.function_observed[3], if1.function_observed[4]);
      errors++;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
