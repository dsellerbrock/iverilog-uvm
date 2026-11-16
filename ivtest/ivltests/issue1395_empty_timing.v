// IEEE 1800-2017/2023 16.12.7, 16.12.22(c): an empty-only
// nonoverlapped antecedent starts its consequent on the current tick.
module issue1395_empty_timing;
  reg clk=0, a=0, b=1;
  integer dp=0, df=0, wp=0, wf=0, fp=0, ff=0;
  integer sp=0, sf=0;
  assert property (@(posedge clk) a[*0] |=> b) dp++; else df++;
  assert property (@(posedge clk) a[*0] |=> ##[0:0] b) wp++; else wf++;
  assert property (@(posedge clk) a[*0] |=> ##[0:0] !b) fp++; else ff++;
  assert property (@(posedge clk) a[*0] |=> ##[1:1] b) sp++; else sf++;
  initial begin
    #5 clk=1; #1 clk=0;
    if (dp!=1 || df!=0 || wp!=1 || wf!=0 || fp!=0 || ff!=1 || sp || sf)
      $fatal(1, "counts direct=%0d/%0d window=%0d/%0d false=%0d/%0d",
             dp,df,wp,wf,fp,ff);
    b=0;
    #4 clk=1; #1 clk=0; $assertoff(0);
    if (dp!=1 || df!=1 || wp!=1 || wf!=1 || fp!=1 || ff!=1 || sp || sf!=1)
      $fatal(1, "second tick counts direct=%0d/%0d window=%0d/%0d false=%0d/%0d shifted=%0d/%0d",
             dp,df,wp,wf,fp,ff,sp,sf);
    $display("PASSED");
  end
endmodule
