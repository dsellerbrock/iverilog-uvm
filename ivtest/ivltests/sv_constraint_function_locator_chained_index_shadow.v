class chained_index_leaf;
  rand int cyc;
endclass
class chained_index_holder;
  rand chained_index_leaf q[5:7];
  rand chained_index_leaf i; // Inner iterator shadows this only in its with.
  rand chained_index_leaf j; // Outer iterator shadows this only in its with.
  rand int n;
  bit fail;
  constraint c {
    q[5].cyc == 0; q[6].cyc == 4; q[7].cyc == 0;
    i.cyc == 88; j.cyc == 77;
    n == ((q.find(i) with (i.index() != 6)).find(j) with
          (j.index() == 1 && j.cyc == 0 && i.cyc == 88)).size();
    fail -> n == 2;
  }
  function new;
    foreach(q[k]) q[k]=new;
    i=new; j=new;
  endfunction
endclass
module test;
  chained_index_holder v; int ok;
  initial begin
    v=new; ok=v.randomize();
    if(!ok || v.n!=1 || v.q[5].cyc!=0 || v.q[6].cyc!=4
       || v.q[7].cyc!=0 || v.i.cyc!=88 || v.j.cyc!=77)
      $fatal(1,"chained locator dense index/sibling shadow");
    v.fail=1; ok=v.randomize();
    if(ok || v.n!=1 || v.q[5].cyc!=0 || v.q[6].cyc!=4
       || v.q[7].cyc!=0 || v.i.cyc!=88 || v.j.cyc!=77)
      $fatal(1,"chained locator dense-index rollback");
    $display("PASSED");
  end
endmodule
