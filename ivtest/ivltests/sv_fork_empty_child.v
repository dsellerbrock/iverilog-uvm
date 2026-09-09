// IEEE 1800-2017/2023 9.3.2, Table 9-1: empty children still terminate.
module main;
  task automatic check_children;
    int hit;
    time started;
    started = $time;
    fork
      begin end
      #2 hit = 1;
    join_any
    if ($time != started || hit != 0) $fatal(1, "empty block child was lost");
    wait fork;
    if ($time != started + 2 || hit != 1) $fatal(1, "automatic child was lost");

    // The named block must remain a child even though its body is empty.
    started = $time;
    fork
      begin : empty_named end
      #2 hit = 2;
    join_any
    if ($time != started || hit != 1) $fatal(1, "named empty child was lost");
    wait fork;
    if ($time != started + 2 || hit != 2) $fatal(1, "named sibling was lost");

    // Constant folding must retain the resulting empty child as well.
    started = $time;
    fork
      if (0) #1 hit = 9;
      #2 hit = 3;
    join_any
    if ($time != started || hit != 2) $fatal(1, "folded if child was lost");
    wait fork;
    if ($time != started + 2 || hit != 3) $fatal(1, "if sibling was lost");

    started = $time;
    fork
      repeat (0) #1 hit = 9;
      #2 hit = 4;
    join_any
    if ($time != started || hit != 3) $fatal(1, "folded repeat child was lost");
    wait fork;
    if ($time != started + 2 || hit != 4) $fatal(1, "repeat sibling was lost");
  endtask

  initial begin
    check_children();
    check_children();
    $display("PASSED");
  end
endmodule
