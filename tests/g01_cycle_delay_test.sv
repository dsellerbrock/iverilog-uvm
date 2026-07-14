// IEEE 1800-2017 14.11 regression: procedural cycle delay `## count`.
// `##N [stmt]` waits N events of the default clocking block (14.12) of
// the enclosing scope, then runs the optional statement. Previously
// `##` did not lex at all (two '#' tokens, syntax error). It now lowers
// to `repeat (N) @(<default clocking>)` at elaboration.
//
// Checks (clk period 10, posedge at 5, 15, 25, ...):
//   1. `##1;` waits exactly one clocking event
//   2. `##2;` waits exactly two
//   3. `##N stmt` runs stmt after the wait
//   4. `##(expr)` parenthesized expression count
//   5. `##id` identifier count evaluated at runtime
//   6. `##0;` completes without waiting for any clocking event
//   7. cycle delays work inside tasks of the same scope

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
    ##0;                                  // 6: no wait
    check_time("##0", 0);

    ##1;                                  // 1: first posedge at t=5
    check_time("##1", 5);

    ##2;                                  // 2: two more edges -> t=25
    check_time("##2", 25);

    ##3 hits++;                           // 3: statement form -> t=55
    check_time("##3 stmt", 55);
    if (hits !== 1) begin
      $display("FAIL: ##3 statement did not run");
      errors++;
    end

    ##(1+1);                              // 4: expression form -> t=75
    check_time("##(1+1)", 75);

    begin : blk
      int k;
      k = 2;
      ##k;                                // 5: identifier form -> t=95
      check_time("##k", 95);
    end

    wait_two_cycles();                    // 7: -> t=115
    check_time("task ##2", 115);

    if (errors == 0) $display("PASS: procedural cycle delays");
    else $display("FAIL: %0d errors", errors);
    $finish(0);
  end
endmodule
