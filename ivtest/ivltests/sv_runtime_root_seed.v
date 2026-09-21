module test;
  int seed_arg;
  int unsigned a, b, c, d;
  initial begin
    seed_arg=-1;
    if ($test$plusargs("ntb_random_seed") &&
        !$value$plusargs("ntb_random_seed=%d",seed_arg))
      $fatal(1,"seed value unavailable");
    a=$urandom; b=$urandom; c=$urandom; d=$urandom;
    $display("seed=%0d %08x %08x %08x %08x",seed_arg,a,b,c,d);
  end
endmodule
