// IEEE 1800-2017/2023 18.13.1: an explicit seed is an input expression.
module top;
  class SeedProbe;
    function int unsigned seeded(int s); return $urandom(s); endfunction
    function int unsigned unseeded(); return $urandom(); endfunction
  endclass
  process p;
  SeedProbe obj;
  string object_state;
  int seeds[2] = '{7, 8};
  int seed = 7;
  int legacy_seed = 7;
  int unsigned a, b, c, d;
  initial begin
    a = $urandom(7);
    c = $urandom(seed + 1);
    d = $urandom(8);
    b = $urandom(7);
    if (a !== b || c !== d) $fatal(1, "seed expression changed sequence");
    if (seed != 7) $fatal(1, "$urandom modified its seed input");
    c = $urandom(seed);
    if (seed != 7) $fatal(1, "$urandom modified a variable seed");
    a = $urandom(seeds[0]);
    b = $urandom(7);
    if (a !== b) $fatal(1, "integral array seed rejected");
    d = $random(legacy_seed);
    if (legacy_seed == 7) $fatal(1, "$random legacy writeback changed");
    p = process::self();
    obj = new();
    p.srandom(17);
    a = $urandom();
    b = $urandom();
    p.srandom(17);
    c = $urandom(17);
    d = $urandom();
    if (a !== c || b !== d)
      $fatal(1, "seeded $urandom missed the process RNG");

    object_state = obj.get_randstate();
    p.srandom(23);
    a = obj.seeded(23);
    if (obj.get_randstate() != object_state)
      $fatal(1, "class $urandom changed object RNG");
    p.srandom(23);
    b = $urandom();
    if (a !== b)
      $fatal(1, "class seeded $urandom missed process RNG");

    p.srandom(31);
    a = obj.unseeded();
    if (obj.get_randstate() != object_state)
      $fatal(1, "class $urandom changed object RNG");
    p.srandom(31);
    b = $urandom();
    if (a !== b)
      $fatal(1, "class $urandom missed process RNG");
    $display("PASSED");
  end
endmodule
