// IEEE 1800-2017/2023 9.6.1: wait fork excludes descendants.
module main;
  int descendant_done;
  int direct_done;

  initial begin
    fork begin
      fork
        begin
          #50;
          descendant_done = 1;
        end
      join_none
    end join_none

    wait fork;
    if ($time != 0 || descendant_done != 0)
      $fatal(1, "wait fork waited for a descendant: time=%0t done=%0d",
             $time, descendant_done);

    #51;
    fork
      begin
        #7;
        direct_done = 1;
      end
    join_none
    wait fork;
    if ($time != 58 || direct_done != 1 || descendant_done != 1)
      $fatal(1, "wait fork missed a direct child: time=%0t direct=%0d descendant=%0d",
             $time, direct_done, descendant_done);

    $display("PASSED");
  end
endmodule
