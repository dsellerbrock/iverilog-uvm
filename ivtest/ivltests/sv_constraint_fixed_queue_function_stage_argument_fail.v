class C;
  rand bit [3:0] q[1][1][$];
  function automatic bit [3:0] identity(bit [3:0] value);
    return value;
  endfunction
  constraint c {
    q[0][0].size() == 1;
    q[0][0][0] == 4'ha;
    identity(q[0][0][0]) == 4'ha;
  }
endclass
module test;
  C c;
  initial begin
    c = new;
    if (!c.randomize()) $fatal(1, "fixed-queue function argument was rejected");
    if (c.q[0][0][0] != 4'ha)
      $fatal(1, "fixed-queue function argument was not solved at its value");
    $display("PASSED");
  end
endmodule
