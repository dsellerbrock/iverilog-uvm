class C;
  rand bit en;
  rand bit [3:0] q[1][1][$];
  function automatic bit identity(bit value);
    return value;
  endfunction
  constraint c {
    q[0][0].size() == 1;
    foreach (q[i,j])
      foreach (q[i][j][k]) q[i][j][k] == 4'ha;
    en == 1;
    identity(en) == 1;
  }
endclass
module test;
  C c;
  initial begin
    c = new;
    if (!c.randomize()) $fatal(1, "randomize failed");
    if (c.q[0][0].size() != 1 || c.q[0][0][0] != 4'ha || c.en != 1)
      $fatal(1, "constraint lost");
    $display("PASSED");
  end
endmodule
