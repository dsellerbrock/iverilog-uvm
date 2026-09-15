class abi_fixed_member_leaf;
  rand int x;
endclass
class abi_fixed_class_member_multidim;
  rand abi_fixed_member_leaf q[2][2];
  bit fail;
  constraint c {
    foreach (q[i,j]) q[i][j].x == i * 10 + j + 3;
    fail -> q[1][1].x == 99;
  }
  function new;
    foreach (q[i,j]) q[i][j] = new;
  endfunction
endclass
module test;
  abi_fixed_class_member_multidim item;
  int ok;
  initial begin
    item = new;
    foreach (item.q[i,j]) item.q[i][j].x = 40 + i*2 + j;
    item.fail = 0;
    ok = item.randomize();
    if (!ok || item.q[0][0].x != 3 || item.q[0][1].x != 4
        || item.q[1][0].x != 13 || item.q[1][1].x != 14)
      $fatal(1, "fixed class member multidim");
    item.fail = 1;
    ok = item.randomize();
    if (ok || item.q[0][0].x != 3 || item.q[0][1].x != 4
        || item.q[1][0].x != 13 || item.q[1][1].x != 14)
      $fatal(1, "fixed class member multidim rollback");
    $display("PASSED");
  end
endmodule
