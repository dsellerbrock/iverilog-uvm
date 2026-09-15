// Former negative reducer: finite repetition now retains both child obligations.
module test;
  reg c1=0, c2=0, a=1, b=1;
  int passes=0, failures=0;
  time failed_at;
  always #10 c1=~c1;
  initial begin #15; c2=1; #1; c2=0; #19; c2=1; #1; c2=0; end
  p: assert property (@(posedge c1) a[*1:2] |=> @(posedge c2) b)
    passes++;
  else begin failures++; failed_at=$time; end
  initial begin
    #11; $assertoff(0);
    #14; b=0;
    #15;
    if (passes != 0 || failures != 1 || failed_at != 35)
      $fatal(1, "parent p%0d f%0d at%0t", passes, failures, failed_at);
    $display("PASSED"); $finish(0);
  end
endmodule
