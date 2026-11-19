module top;
  bit ready = 1;

  task automatic exercise(output int zero_count, continue_count, break_count,
                          singleton_count);
    zero_count = 0;
    continue_count = 0;
    break_count = 0;
    singleton_count = 0;
    repeat (2) begin
      forever begin
        do while (0) ; while (0);
        break;
      end
      repeat (0) zero_count += 1;
      repeat (1) begin
        continue_count += 1;
        continue;
        continue_count += 100;
      end
      repeat (1) begin
        break_count += 1;
        break;
        break_count += 100;
      end
      while (0) begin end
      do begin singleton_count += 1; end while (0);
      while (0) begin : named_empty end
    end
  endtask

  task automatic wait_ready;
    wait (ready);
  endtask

  initial begin
    int zero_count, continue_count, break_count, singleton_count;
    $probe_loop_bodies;
    wait_ready();
    exercise(zero_count, continue_count, break_count, singleton_count);
    if (zero_count !== 0 || continue_count !== 2 || break_count !== 2 ||
        singleton_count !== 2)
      $fatal(1, "Unexpected execution counts %0d %0d %0d %0d",
             zero_count, continue_count, break_count, singleton_count);
    $display("Execution counts: %0d %0d %0d %0d",
             zero_count, continue_count, break_count, singleton_count);
    $display("PASSED");
    $finish(0);
  end
endmodule
