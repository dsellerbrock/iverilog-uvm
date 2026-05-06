// p08: G08 — event.triggered — non-blocking wait after ->
// Mirrors the g08 test: wait(e.triggered) sees the trigger set
// in the same time step without a delta-cycle race.
module top;
  event e;
  int hits;

  initial begin
    fork
      begin wait(e.triggered); hits++; end
      begin @(e);               hits++; end
    join_none

    #1;
    -> e;
    #1;

    if (hits == 2)
      $display("PASS: event.triggered p08");
    else
      $display("FAIL: hits=%0d expected=2", hits);
    $finish;
  end
endmodule
