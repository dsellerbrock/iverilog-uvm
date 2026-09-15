class abi_locator_static_leaf;
  int x;
endclass
class abi_locator_static_store;
  static abi_locator_static_leaf q[2][2];
endclass
class abi_locator_scoped_static_count;
  rand int n;
  bit fail;
  constraint c {
    n == (abi_locator_static_store::q[0].find(item) with
      (item.x > 5)).size();
    fail -> n == 3;
  }
endclass
module test;
  abi_locator_scoped_static_count item;
  int ok;
  initial begin
    foreach (abi_locator_static_store::q[i,j])
      abi_locator_static_store::q[i][j] = new;
    abi_locator_static_store::q[0][0].x = 2;
    abi_locator_static_store::q[0][1].x = 7;
    item = new;
    item.fail = 0;
    ok = item.randomize();
    if (!ok || item.n != 1) $fatal(1, "scoped static locator initial");
    abi_locator_static_store::q[0][0].x = 9;
    ok = item.randomize();
    if (!ok || item.n != 2) $fatal(1, "scoped static locator changed state");
    item.fail = 1;
    ok = item.randomize();
    if (ok || item.n != 2) $fatal(1, "scoped static locator rollback");
    $display("PASSED");
  end
endmodule
