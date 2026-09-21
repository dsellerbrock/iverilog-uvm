module main;
 int a[2][3];
 int b[3];
 integer i;
 initial begin
  b='{11,12,13};i=1;a[i]=b;
  if(a[1][0]!=11 || a[1][2]!=13) $fatal(1,"whole source blocking");
  i=0;a[i]<=b;i=1;b='{21,22,23};#1;
  if(a[0][0]!=11 || a[0][2]!=13) $fatal(1,"whole source NBA capture");
  $display("PASSED");
 end
endmodule
