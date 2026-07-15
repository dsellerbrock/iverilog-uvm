// M8 tail T3+T4:
//   T3 — clocking_decl_assign (IEEE 1800-2017 A.6.11/14.3):
//        `input a = hier.sig;` declares clockvar `a` sampling a
//        (possibly hierarchical) signal with the usual #1step
//        semantics.
//   T4 — scalar cycle-delay drive `x <= ##N v` (14.16): the cycle
//        count uses the DEFAULT clocking block of the enclosing
//        scope; the value is captured at issue time.

`timescale 1ns/1ns

module m8_da_sub;
  logic [7:0] deep = 8'h11;
endmodule

module m8_decl_assign_test;
  logic clk = 0;
  logic [7:0] x = 8'h00;
  int errors = 0;

  always #5 clk = ~clk;   // edges at 5, 15, 25, ...

  m8_da_sub u_sub();

  // T3: clockvar sampling a hierarchical signal.
  default clocking cb @(posedge clk);
    input probe = u_sub.deep;
  endclocking

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    // T3: first edge samples the initial value.
    @(cb);                        // t=5
    check(cb.probe == 8'h11, "decl_assign clockvar samples hier signal");

    // The raw signal changes mid-cycle; the sample holds.
    #2 u_sub.deep = 8'h22;        // t=7
    #1;
    check(cb.probe == 8'h11, "decl_assign sample holds between edges");
    @(cb);                        // t=15
    check(cb.probe == 8'h22, "next edge picks up the new value");

    // T4: scalar ##N drive counts default-clocking events.
    x = 8'h00;
    x <= ##2 8'hAB;               // issued at t=15; lands at t=35
    @(posedge clk);               // t=25
    #1;
    check(x == 8'h00, "scalar ##2 has not landed after one edge");
    @(posedge clk);               // t=35
    #1;
    check(x == 8'hAB, "scalar ##2 lands at the second default-clocking event");

    if (errors == 0)
      $display("PASSED: all m8 decl-assign / scalar cycle-drive checks");
    else
      $display("FAILED: %0d m8 decl-assign checks", errors);
    $finish(0);
  end
endmodule
