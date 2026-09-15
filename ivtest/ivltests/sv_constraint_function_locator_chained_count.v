class chained_leaf;
  rand int cyc;
endclass
class chained_holder;
  rand chained_leaf q[3];
  rand chained_leaf j; // The second locator iterator shadows this property.
  rand int n;
  bit fail;
  constraint c {
    q[0].cyc == 0; q[1].cyc == 4; q[2].cyc == 0;
    j.cyc == 77;
    n == ((q.find(i) with (1)).find(j) with (j.cyc == 0)).size();
    fail -> n == 3;
  }
  function new;
    foreach(q[i]) q[i]=new;
    j=new;
  endfunction
endclass
module test;
  chained_holder v; int ok;
  initial begin
    v=new; ok=v.randomize();
    if(!ok || v.n!=2 || v.q[0].cyc!=0 || v.q[1].cyc!=4
       || v.q[2].cyc!=0 || v.j.cyc!=77)
      $fatal(1,"chained locator count/shadow");
    v.fail=1; ok=v.randomize();
    if(ok || v.n!=2 || v.q[0].cyc!=0 || v.q[1].cyc!=4
       || v.q[2].cyc!=0 || v.j.cyc!=77)
      $fatal(1,"chained locator rollback");
    $display("PASSED");
  end
endmodule
