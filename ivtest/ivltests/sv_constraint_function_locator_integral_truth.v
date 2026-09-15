class locator_truth;
  rand int a[3];
  rand int n;
  bit fail;
  constraint c {
    a[0] == 0; a[1] == 2; a[2] == 7;
    n == (a.find(item) with (item)).size();
    fail -> n == 1;
  }
endclass
module test;
  locator_truth v; int ok;
  initial begin
    v=new; v.n=37; v.a[0]=31; v.a[1]=32; v.a[2]=33;
    ok=v.randomize();
    if(!ok || v.n!=2 || v.a[0]!=0 || v.a[1]!=2 || v.a[2]!=7)
      $fatal(1,"locator integral truthiness ok=%0d n=%0d",ok,v.n);
    v.fail=1; ok=v.randomize();
    if(ok || v.n!=2 || v.a[0]!=0 || v.a[1]!=2 || v.a[2]!=7)
      $fatal(1,"locator integral truthiness rollback");
    $display("PASSED");
  end
endmodule
