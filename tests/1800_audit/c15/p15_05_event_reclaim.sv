// IEEE 1800-2017/2023 §15.5.5: assigning null reclaims an event variable.
module test;
  event e1, e2;
  initial begin
    e1 = e2;
    if (!(e1 == e2)) $fatal(1, "FAIL 15.5.5: event assignment did not merge");
    e1 = null;
    if (e1 == e2) $fatal(1, "FAIL 15.5.5: null assignment did not reclaim e1");
    if (!(e1 == null)) $fatal(1, "FAIL 15.5.5: reclaimed e1 is not null");
    $display("PASS 15.5.5 event assignment and reclaim");
  end
endmodule
