module issue2520_disable_fork_named_block;
  int gc;

  initial begin : A
    fork
      begin
        fork
          #10 gc++;
        join_none
      end
    join_none

    #1 disable fork;
    #20;
    if (gc != 0)
      $fatal(1, "disable fork left a descendant of a finished child running");
    $display("PASS disable fork terminates descendants in a named block");
    $display("PASSED");
    $finish;
  end
endmodule
