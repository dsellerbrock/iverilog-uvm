// IEEE 1800-2017/2023 12.4 / 12.6.2: an if predicate may be a series of
// clauses joined by &&&; they are evaluated left to right, a pattern's
// variables are visible to later clauses and to the true arm, and the else
// arm runs when any clause fails.
typedef union tagged { void Invalid; int Valid; } VInt;
typedef union tagged { int Jmp; struct { int cc; int addr; } JmpC; } Instr;
module issue780_if_tand_predicate;
  VInt v;
  Instr e;
  int y = 1, z = 0, hit, calls = 0, a_seen, b_seen;
  bit ok = 1;

  function automatic bit probe(input bit r);
    calls++;
    return r;
  endfunction

  task check(bit c, string what);
    if (!c) begin $display("FAILED: %s", what); ok = 0; end
  endtask

  task automatic guarded(input int x, input int delay, output int seen);
    if (x &&& x > 0) begin #(delay); seen = 1; end
    else seen = 2;
  endtask

  initial begin
    v = tagged Valid (5);
    if (y &&& (y > 0)) hit = 1; else hit = 2;
    check(hit == 1, "plain clauses true");
    if (y &&& z) hit = 1; else hit = 2;
    check(hit == 2, "plain clause false");
    if (v matches tagged Valid .n &&& n == 5) hit = n * 4; else hit = 21;
    check(hit == 20, "pattern then guard");
    if (v matches tagged Valid .n &&& n > 7) hit = n; else hit = -1;
    check(hit == -1, "guard false takes else");
    v = tagged Invalid;
    if (v matches tagged Valid .n &&& n == 5) hit = 1; else hit = 2;
    check(hit == 2, "pattern false takes else");

    e = tagged JmpC '{cc:3, addr:44};
    if (e matches tagged JmpC .j &&& j matches '{cc:.c, addr:.a} &&& c == 3)
      hit = a;
    else
      hit = 0;
    check(hit == 44, "chained patterns");

    calls = 0;
    if (probe(0) &&& probe(1)) hit = 1; else hit = 2;
    check(hit == 2 && calls == 1, "short-circuit left to right");
    calls = 0;
    if (probe(1) &&& probe(1) &&& probe(1)) hit = 1;
    check(hit == 1 && calls == 3, "three clauses");

    fork
      guarded(1, 5, a_seen);
      guarded(0, 1, b_seen);
    join
    check(a_seen == 1 && b_seen == 2, "else arm per activation");

    if (ok) $display("PASSED");
  end
endmodule
