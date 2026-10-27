// IEEE 1800-2017 14.11 regression: procedural cycle delay `## count`.
// `##N [stmt]` waits N events of the default clocking block (14.12) of
// the enclosing scope, then runs the optional statement. Previously
// `##` did not lex at all (two '#' tokens, syntax error). It now lowers
// to `repeat (N) @(<default clocking>)` at elaboration.
//
// Checks (clk period 10, posedge at 5, 15, 25, ...):
//   1. pre-event `##0;` waits for the first clocking event (14.11)
//   2. `##1;` waits exactly one later clocking event
//   3. `##2;` waits exactly two
//   4. `##N stmt` runs stmt after the wait
//   5. `##(expr)` parenthesized expression count
//   6. `##id` identifier count evaluated at runtime
//   7. cycle delays work inside tasks of the same scope
// Starting at t=0, the checked completion times are 5, 15, 35, 65, 85, 105, and 125.

`timescale 1ns/1ns

module g01_cycle_delay_test;
  logic clk = 0;
  int hits = 0;
  int errors = 0;

  always #5 clk = ~clk;

  default clocking dcb @(posedge clk);
  endclocking

  task automatic check_time(string what, time want);
    if ($time != want) begin
      $display("FAIL: %s at t=%0t (want %0t)", what, $time, want);
      errors++;
    end
  endtask

  task automatic wait_two_cycles;
    ##2;  // 7: cycle delay inside a task body
  endtask

  initial begin
    ##0;                                  // 1: pre-event delay waits for posedge at t=5
    check_time("##0", 5);

    ##1;                                  // 2: next posedge at t=15
    check_time("##1", 15);

    ##2;                                  // 3: two more edges -> t=35
    check_time("##2", 35);

    ##3 hits++;                           // 4: statement form -> t=65
    check_time("##3 stmt", 65);
    if (hits !== 1) begin
      $display("FAIL: ##3 statement did not run");
      errors++;
    end

    ##(1+1);                              // 5: expression form -> t=85
    check_time("##(1+1)", 85);

    begin : blk
      int k;
      k = 2;
      ##k;                                // 6: identifier form -> t=105
      check_time("##k", 105);
    end

    wait_two_cycles();                    // 7: -> t=125
    check_time("task ##2", 125);

    if (errors == 0) $display("PASS: procedural cycle delays");
    else $display("FAIL: %0d errors", errors);
    $finish(0);
  end
endmodule
