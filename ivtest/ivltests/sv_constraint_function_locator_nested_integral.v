class locator_nested_integral;
  rand int q[2][3];
  rand int row[2]; // The outer iterator named row shadows this property.
  rand int n;
  bit fail;
  constraint c {
    q[0][0]==0; q[0][1]==2; q[0][2]==7;
    q[1][0]==0; q[1][1]==0; q[1][2]==9;
    row[0]==31; row[1]==32;
    n == (q.find(row) with
      ((row.find(item) with (item > 5)).size() > 0)).size();
    fail -> n == 1;
  }
endclass
module test;
  locator_nested_integral v; int ok;
  initial begin
    v=new; ok=v.randomize();
    if(!ok || v.n!=2 || v.row[0]!=31 || v.row[1]!=32
       || v.q[0][2]!=7 || v.q[1][2]!=9)
      $fatal(1,"nested integral locator count/shadow");
    v.fail=1; ok=v.randomize();
    if(ok || v.n!=2 || v.row[0]!=31 || v.row[1]!=32
       || v.q[0][2]!=7 || v.q[1][2]!=9)
      $fatal(1,"nested integral locator rollback");
    $display("PASSED");
  end
endmodule
