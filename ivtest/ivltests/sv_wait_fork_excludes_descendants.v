module main;
  int descendant_done;
  int direct_done;
  time start_time;

  initial begin
    start_time = $time;
    fork
      begin
        fork
          #10 descendant_done = 1;
        join_none
      end
    join_none
    wait fork;
    if ($time != start_time || descendant_done != 0)
      $fatal(1, "wait fork included a descendant");
    $display("PASS wait fork excludes descendants");

    start_time = $time;
    fork
      #7 direct_done = 1;
    join_none
    wait fork;
    if ($time - start_time != 7 || direct_done != 1)
      $fatal(1, "wait fork did not wait for its immediate child");
    $display("PASS wait fork waits for immediate child");

    #3;
    if (descendant_done != 1)
      $fatal(1, "detached descendant did not continue");
    $display("PASS descendant continues after wait fork");
  end
endmodule
