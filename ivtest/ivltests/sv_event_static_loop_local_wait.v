module sv_event_static_loop_local_wait;
  logic clk = 1'b0;
  always #5 clk = ~clk;

  // Keep this task static; making it automatic masks the missing event context.
  task run_test;
    fork
      begin
        for (int j = 0; j < 1; j++) begin
          int local_value;
          local_value = 3;
          if (local_value != 3)
            $fatal(1, "loop-local initialization lost");
          @(posedge clk);
        end
      end
      begin
        @(posedge clk);
      end
    join
    @(posedge clk);
  endtask

  initial begin
    run_test();
    $display("PASSED");
    $finish;
  end
endmodule
