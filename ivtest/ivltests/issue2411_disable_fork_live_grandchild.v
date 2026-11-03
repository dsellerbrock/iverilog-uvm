module issue2411_disable_fork_live_grandchild;
  int grandchildren;

  task automatic kills();
    for (int i = 0; i < 2; i++) begin
      fork begin
        fork begin #5; grandchildren++; end join_none
        #5;
      end join_none
      #1;
    end
    disable fork;
    #10;
    if (grandchildren != 0)
      $fatal(1, "disable fork left %0d live grandchild processes", grandchildren);
    $display("PASS disable fork terminates live grandchildren");
    $display("PASSED");
  endtask

  initial begin
    kills();
    $finish;
  end
endmodule
