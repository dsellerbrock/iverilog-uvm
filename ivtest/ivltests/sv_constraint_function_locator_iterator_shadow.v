class locator_shadow_leaf;
  int x;
endclass
class locator_shadow;
  rand locator_shadow_leaf q[2][2];
  rand int row[2]; // Must lose to the outer locator iterator named row.
  rand int n;
  bit fail;
  constraint c {
    row[0] == 31; row[1] == 32;
    n == (q.find(row) with
      ((row.find(item) with (item.x > 5)).size() > 0)).size();
    fail -> n == 3;
  }
  function new;
    foreach(q[i,j]) q[i][j]=new;
  endfunction
endclass
module test;
  locator_shadow v; int ok;
  initial begin
    v=new;
    v.q[0][0].x=2; v.q[0][1].x=7;
    v.q[1][0].x=9; v.q[1][1].x=4;
    ok=v.randomize();
    if(!ok || v.n!=2 || v.row[0]!=31 || v.row[1]!=32)
      $fatal(1,"nested locator iterator shadow");
    v.fail=1; ok=v.randomize();
    if(ok || v.n!=2 || v.row[0]!=31 || v.row[1]!=32)
      $fatal(1,"nested locator shadow rollback");
    $display("PASSED");
  end
endmodule
