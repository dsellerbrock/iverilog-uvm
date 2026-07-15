// M8 tail T2: global clocking + $global_clock (IEEE 1800-2017 14.14,
// gap G59).
//
// `global clocking [id] @(event); endclocking` declares the design's
// global clock; `@($global_clock)` waits on its clocking event, from
// the declaring module or any scope below it.
//
// Checks:
//   1. @($global_clock) waits for the global clocking event.
//   2. It resolves from a nested submodule scope (hierarchy walk).
//   3. A named global clocking coexists with an ordinary default
//      clocking in the same module.

`timescale 1ns/1ns

module m8_gclk_sub;
  int sub_hits = 0;
  initial begin
    repeat (3) @($global_clock);
    sub_hits = 3;
  end
endmodule

module m8_global_clocking_test;
  logic gclk = 0;
  logic [7:0] d = 8'h00;
  int errors = 0;

  always #5 gclk = ~gclk;   // posedges at 5, 15, 25, ...

  global clocking sys_gclk @(posedge gclk); endclocking

  // 3: ordinary default clocking coexists.
  default clocking cb @(posedge gclk);
    input d;
  endclocking

  m8_gclk_sub u_sub();

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    // 1: @($global_clock) waits for the next posedge.
    @($global_clock);
    check($time == 5, "@($global_clock) waits for the clocking event");
    @($global_clock);
    check($time == 15, "second wait hits the next edge");

    // 3: default clocking still works alongside. Note the strict
    // semantics: we are IN the t=15 edge step (woken by
    // @($global_clock) on the raw edge), so this @(cb) catches the
    // CURRENT edge's trigger (fires after the NBA region of this
    // step) and its #1step sample excludes the same-step blocking
    // write; the next edge samples it.
    d = 8'h42;
    @(cb);
    check($time == 15 && cb.d == 8'h00,
          "same-step @(cb) resumes at this edge with the pre-step sample");
    @(cb);
    check($time == 25 && cb.d == 8'h42,
          "next edge samples the settled value");

    // 2: the submodule's waits complete after 3 edges (t=25).
    #11;   // t > 25+
    check(u_sub.sub_hits == 3, "$global_clock resolves in a submodule");

    if (errors == 0)
      $display("PASSED: all m8 global clocking checks");
    else
      $display("FAILED: %0d m8 global clocking checks", errors);
    $finish(0);
  end
endmodule
