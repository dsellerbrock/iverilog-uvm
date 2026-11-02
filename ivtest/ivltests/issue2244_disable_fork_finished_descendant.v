module issue2244_disable_fork_finished_descendant;
  int gc;

  initial begin
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
    $display("PASS disable fork terminates descendants of finished children");
    $display("PASSED");
    $finish;
  end
endmodule
