class abi_locator_leaf;
  int x;
endclass
class abi_locator_fixed_class_count;
  rand abi_locator_leaf q[2][2];
  rand int n;
  bit fail;
  constraint c {
    n == (q.find(row) with
      ((row.find(item) with (item.x > 5)).size() > 0)).size();
    fail -> n == 3;
  }
  function new;
    foreach (q[i,j]) q[i][j] = new;
  endfunction
endclass
module test;
  abi_locator_fixed_class_count value;
  int ok;
  initial begin
    value = new;
    value.q[0][0].x = 2;
    value.q[0][1].x = 7;
    value.q[1][0].x = 9;
    value.q[1][1].x = 4;
    value.fail = 0;
    ok = value.randomize();
    if (!ok || value.n != 2) $fatal(1, "fixed class locator count");
    value.fail = 1;
    ok = value.randomize();
    if (ok || value.n != 2) $fatal(1, "fixed class locator rollback");
    $display("PASSED");
  end
endmodule
