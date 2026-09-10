// IEEE 1800-2017/2023 6.21, 9.4.2: each automatic activation's
// previous value determines its transition, including 0->X and X->1.
module main;
  time observed[2];
  bit broadcast;
  int wakes;
  int factorial;

  task automatic check_times();
    if (observed[0] != 2 || observed[1] != 3)
      $fatal(1, "wrong activation history %0t,%0t", observed[0], observed[1]);
  endtask

  task automatic watch_bit(input bit initial_value);
    logic [3:0] value;
    time origin;
    origin = $time;
    value = initial_value ? 4'b0100 : 4'b0000;
    #1;
    begin
      int local_state;
      fork
        begin
          @(posedge value[2] or negedge broadcast);
          observed[initial_value] = $time - origin;
          local_state++;
        end
        begin #1; value = 4'b0x00; #1; value = 4'b0100; end
      join
      if (local_state != 1) $fatal(1, "missing edge waiter");
    end
  endtask

  task automatic watch_real(input bit initial_value);
    real value;
    time origin;
    origin = $time;
    value = initial_value ? 20.0 : 10.0;
    #1;
    begin
      int local_state;
      fork
        begin @(value); observed[initial_value] = $time - origin; local_state++; end
        begin #1; value = 20.0; #1; value = 21.0; end
      join
      if (local_state != 1) $fatal(1, "missing real waiter");
    end
  endtask

  task automatic watch_string(input bit initial_value);
    string value;
    time origin;
    origin = $time;
    value = initial_value ? "b" : "a";
    #1;
    begin
      int local_state;
      fork
        begin @(value); observed[initial_value] = $time - origin; local_state++; end
        begin #1; value = "b"; #1; value = "c"; end
      join
      if (local_state != 1) $fatal(1, "missing string waiter");
    end
  endtask

  task automatic watch_broadcast();
    #1;
    begin
      int local_state;
      @(posedge broadcast);
      local_state++;
      wakes += local_state;
    end
  endtask

  task automatic watch_default();
    bit [3:0] value;
    time origin;
    origin = $time;
    begin
      int local_state;
      fork
        begin
          @(posedge value[0]);
          if ($time - origin != 2) $fatal(1, "default history changed edge time");
          local_state++;
        end
        begin #1; value[2:1] = 0; #1; value[0] = 1; end
      join
      if (local_state != 1) $fatal(1, "default history lost edge");
    end
  endtask

  task automatic recursive(input int n, output int result);
    begin : activation
      int child_result;
      fork
        begin
          if (n > 1) recursive(n - 1, child_result);
          else child_result = 1;
          #1 result = n * child_result;
        end
        begin @result; end
      join
    end
  endtask

  initial begin
    // Reuse both ancestor and child activation storage after all waiters exit.
    repeat (3) begin
      watch_default();
      fork watch_bit(0); watch_bit(1); join
      check_times();
      fork watch_real(0); watch_real(1); join
      check_times();
      fork watch_string(0); watch_string(1); join
      check_times();
    end
    fork
      watch_broadcast();
      watch_broadcast();
      begin #2; broadcast = 1; end
    join
    if (wakes != 2) $fatal(1, "static broadcast lost a waiter");
    recursive(4, factorial);
    if (factorial != 24) $fatal(1, "recursive event selected caller frame");
    $display("PASSED");
    $finish(0);
  end
  initial begin #1000; $fatal(1, "event wait did not complete"); end
endmodule
