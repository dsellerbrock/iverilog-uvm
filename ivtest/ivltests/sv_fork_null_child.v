// IEEE 1800-2017/2023 9.3.2, Table 9-1: null children are processes.
module main;
  int hit;
  initial begin
    // A sequential null remains a no-op; join still waits for all children.
    ;
    fork
      ;
      #2 hit = 1;
    join
    if ($time != 2 || hit != 1) $fatal(1, "join lost its delayed child");

    // The null child terminates now; the other child survives join_any.
    fork
      ;
      #3 hit = 2;
    join_any
    if ($time != 2 || hit != 1) $fatal(1, "join_any lost its null child");
    wait fork;
    if ($time != 5 || hit != 2) $fatal(1, "join_any lost its remaining child");

    // Spawned children cannot execute before the parent blocks.
    fork
      ;
      hit = 3;
      #2;
    join_none
    if ($time != 5 || hit != 2) $fatal(1, "join_none suspended its parent");
    wait fork;
    if ($time != 7 || hit != 3) $fatal(1, "wait fork lost a delayed null body");
    $display("PASSED");
  end
endmodule
