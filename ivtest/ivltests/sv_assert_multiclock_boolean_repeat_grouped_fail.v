// A grouped antecedent may produce two children, but only one parent verdict.
module test;
  reg c1=0, c2=0, a=1, b=1, good=1;
  int passes=0, failures=0;
  time failed_at;
  always #10 c1=~c1;
  initial begin #35; c2=1; #1; c2=0; #39; c2=1; #1; c2=0; end
  assert property (@(posedge c1) (a ##1 b)[*1:2] |=> @(posedge c2) good)
    passes++;
  else begin failures++; failed_at=$time; end
  initial begin
    #11; $assertoff(0);
    #54; good=0;
    #11;
    if (passes != 0 || failures != 1 || failed_at != 75)
      $fatal(1, "parent verdict p%0d f%0d at%0t", passes, failures, failed_at);
    $display("PASSED");
    $finish(0);
  end
endmodule
