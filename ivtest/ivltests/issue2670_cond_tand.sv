// IEEE 1800-2017/2023 11.4.11 and 12.6.3: &&& clauses are allowed in a
// conditional-operator predicate, including a pattern followed by a guard.
module top;
  typedef union tagged { int A; void B; } u_t;
  u_t u;
  int a, b, y, z, chained;
  initial begin
    a = 1; b = 0;
    y = a &&& b ? 10 : 20;
    chained = a &&& (a == 1) &&& (b == 0) ? 30 : 40;
    u = tagged A 5;
    z = u matches tagged A .v &&& v > 3 &&& v == 5 ? v : -1;
    if (y === 20 && z === 5 && chained === 30) $display("PASSED");
    else $display("FAILED y=%0d z=%0d chained=%0d", y, z, chained);
  end
endmodule
