// IEEE 1800-2017/2023 13.4.4 and 9.3.2: every function fork child waits.
module main;
  int hit;
  int other;

  // A named sequential block still executes within its calling function.
  function automatic int next_value(input int value);
    begin : continuation
      int copy;
      copy = value;
      copy++;
      return copy;
    end
  endfunction

  function automatic void launch(input int value);
    fork
      hit = value;
      other = value + 1;
      ;
      begin end
    join_none
  endfunction

  // Task-legal delayed statements remain legal in the spawned processes.
  function automatic void launch_delayed(input int value);
    fork
      #1 hit = value;
      #2 other = value + 1;
    join_none
  endfunction

  initial begin
    if (next_value(8) != 9) $fatal(1, "function continuation did not finish");
    launch(4);
    if (hit != 0 || other != 0) $fatal(1, "function child ran before parent blocked");
    #0;
    if (hit != 4 || other != 5) $fatal(1, "function children lost their automatic value");
    launch_delayed(6);
    if ($time != 0 || hit != 4 || other != 5)
      $fatal(1, "background delay suspended the calling function");
    #3;
    if (hit != 6 || other != 7)
      $fatal(1, "delayed function children lost their automatic value");
    $display("PASSED");
  end
endmodule
