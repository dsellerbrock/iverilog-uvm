// M13: let declarations (IEEE 1800-2017 11.13) — real expression-macro
// substitution. Covers: multi-arg lets, argless lets, default and
// named arguments, lets calling other lets, bit/part-selects of
// formals, array-word selects through formals, lets over parameters,
// use in continuous assigns and procedural contexts.
module m13_let_test_top;
  logic [7:0] a = 8'd7, b = 8'd9;
  logic [7:0] sel_v = 8'h5A;
  logic [7:0] mem [0:3];
  logic en = 1;
  int n = 5;
  logic [7:0] w;

  let max2(x, y) = (x > y) ? x : y;
  let sq(v) = v * v;
  let ready = en && (n > 3);
  let scaled(v, f = 2) = v * f;
  let both(x, y) = max2(x, y) + sq(x);
  let nib(v) = v[7:4];
  let word(m, i) = m[i];
  localparam int LP = 3;
  let plus_lp(x) = x + LP;

  assign w = nib(sel_v);

  int errors = 0;
  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL: %s got=%0d expected=%0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    mem[2] = 8'd42;
    #1;
    check("max2", max2(a, b), 9);
    check("sq", sq(4), 16);
    check("ready", ready ? 1 : 0, 1);
    check("scaled default", scaled(10), 20);
    check("scaled explicit", scaled(10, 3), 30);
    check("scaled named", scaled(.f(4), .v(5)), 20);
    check("let-calls-let", both(3, 8), 17);
    check("part select of formal", nib(sel_v), 5);
    check("continuous assign", w, 5);
    check("array word via formal", word(mem, 2), 42);
    check("parameter in body", plus_lp(4), 7);
    if (errors == 0) $display("PASS: m13 let semantics");
    else $display("FAIL: m13 let semantics (%0d errors)", errors);
    $finish(0);
  end
endmodule
