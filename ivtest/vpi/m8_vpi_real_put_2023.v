module test;
  real target;
  real mem [0:0];

  initial begin
    target = 0;
    mem[0] = 0;
    $check_real_put;
    $finish;
  end
endmodule
