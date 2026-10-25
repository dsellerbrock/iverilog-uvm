class C;
  rand bit [3:0] a, b, c;
  function automatic bit [3:0] f(bit [3:0] value);
    f = value;
  endfunction
  constraint k { b == f(a); }
endclass

module test;
  C item;
  bit [3:0] old_a, old_b, old_c;
  string state;

  initial begin
    item = new;
    item.srandom(17);
    old_a = item.a;
    old_b = item.b;
    old_c = item.c;
    state = item.get_randstate();
    if (item.randomize() with { c == 4'd1; c == 4'd2; })
      $fatal(1, "intrinsic contradiction unexpectedly succeeded");
    if (item.a !== old_a || item.b !== old_b || item.c !== old_c)
      $fatal(1, "intrinsic failure changed object fields");
    if (item.get_randstate() != state)
      $fatal(1, "intrinsic failure changed RNG state");
    $display("PASSED intrinsic_failure_rng_rollback");
    $display("PASSED");
  end
endmodule
