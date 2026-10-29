module tb;
  int a[3];
  int seen[3];

  initial begin
    foreach (a[i]) fork
      begin
        #1;
        seen[i] = i + 1;
      end
    join_none

    wait fork;
    if (seen[0] !== 1 || seen[1] !== 2 || seen[2] !== 3)
      $fatal(1, "foreach indices were not captured per iteration: %0d,%0d,%0d",
             seen[0], seen[1], seen[2]);
    $display("PASSED");
  end
endmodule
