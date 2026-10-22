// IEEE 1800-2017 §18.12 (pp. 536-538) / IEEE 1800-2023 §18.12 (pp. 558-560).
module test;
  bit [15:0] addr;
  bit [31:0] data;

  task run_checks();
    int a, b, c, success;
    int length = 100;

    success = randomize(addr, data);
    if (!success) $fatal(1, "randomize(addr, data) failed");

    a = 0; b = 0; c = 0;
    success = std::randomize(a, b, c) with { a < b; a + b < length; c == a + b; };
    if (!success || a >= b || a + b >= length || c != a + b)
      $fatal(1, "std::randomize(a, b, c) with constraints failed");

    a = 10; b = 20;
    success = std::randomize(a, b) with { b - a == length; };
    if (!success || b - a != length)
      $fatal(1, "std::randomize with scope state variable failed");

    success = std::randomize(a) with { a == 1; a == 2; };
    if (success !== 0)
      $fatal(1, "std::randomize returned 1 for an infeasible constraint");

    $display("PASS scope randomize clause 18.12");
  endtask

  initial run_checks();
endmodule
