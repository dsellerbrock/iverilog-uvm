// M3B-15: constraint expression WIDTH (IEEE 1800-2017 11.6.1,
// Table 11-21).
//
// A constraint expression is an ordinary SystemVerilog expression, so
// its arithmetic is evaluated at the CONTEXT width -- the widest
// operand of the comparison it feeds -- and only then truncated. The
// solver instead evaluated it at the OPERAND width, so
//
//     rand bit [7:0] a, b;
//     constraint c { a + b == 300; }
//
// wrapped the sum mod 256 and reported the constraint UNSATISFIABLE:
// randomize() returned 0 for a set with 155 solutions. The same defect
// in the other direction is silent rather than loud:
//
//     rand bit [7:0] a, b;  rand int s;
//     constraint c { s == a * b; }
//
// solved `s' to the low 8 bits of the product, so `s' disagreed with
// `a * b' computed anywhere else.
//
// The set operators had their own version of it. `inside' compares like
// `==' (11.4.13), so each member sizes WITH the subject -- but members
// were truncated DOWN to the subject's width, rewriting
// `x inside {[0:300]}' on an 8-bit x into `x inside {[0:44]}', and
// `dist' built its branch values at the subject's width for the same
// silent effect.
//
// Arithmetic is now built at full precision and truncated to the
// context width at the comparison, which gets both directions right: a
// wide context does not wrap, and a narrow one still does.

class Wide;
  rand bit [7:0] a, b;
  rand int       s;
  constraint c_sum  { a + b == 300; }
  constraint c_prod { s == a * b; }
endclass

class Narrow;
  rand bit [7:0] a, b, c;
  constraint c_big  { a > 150; b > 150; }
  constraint c_wrap { c == a + b; }        // 8-bit context: MUST wrap
endclass

class Sets;
  rand bit [7:0] x;
  rand bit [7:0] y;
  rand bit [7:0] z;
  constraint c_in   { x inside {[0:300]}; }   // bound must not truncate
  constraint c_in2  { y inside {[200:255]}; }
  constraint c_dist { z dist {[0:300] := 1}; }
endclass

class Container;
  rand bit [7:0] x;
  int  tbl[$];                                // 300 cannot fit an 8-bit x
  constraint c_q { x inside {tbl}; }
endclass

class Mixed;
  rand bit [3:0] n;
  rand int       big;
  constraint c1 { big == n * 1000; }          // 4-bit times a 32-bit literal
  constraint c2 { n > 8; }
endclass

module main;

  Wide   w;
  Narrow nn;
  Sets   st;
  Mixed  m;
  Container ct;

  int fails = 0;
  int hi_x, hi_z, n;

  initial begin

    // ---- a wide context does not wrap ----
    w = new();
    for (int i = 0; i < 20; i++) begin
      if (!w.randomize()) begin
        fails++;
        $display("FAILED -- `a + b == 300' reported UNSAT (155 solutions exist)");
      end else begin
        if ((w.a + w.b) != 300) begin
          fails++;
          $display("FAILED -- a=%0d b=%0d sum=%0d (want 300)", w.a, w.b, w.a + w.b);
        end
        if (w.s != (w.a * w.b)) begin
          fails++;
          $display("FAILED -- s=%0d but a*b=%0d (a=%0d b=%0d)",
                   w.s, w.a * w.b, w.a, w.b);
        end
      end
    end

    // ---- a narrow context still wraps ----
    nn = new();
    for (int i = 0; i < 20; i++) begin
      if (!nn.randomize()) begin
        fails++;
        $display("FAILED -- `c == a + b' into an 8-bit c reported UNSAT");
      end else begin
        if (nn.c !== ((nn.a + nn.b) & 8'hff)) begin
          fails++;
          $display("FAILED -- 8-bit context: a=%0d b=%0d c=%0d (want %0d)",
                   nn.a, nn.b, nn.c, (nn.a + nn.b) & 8'hff);
        end
        if (nn.a <= 150 || nn.b <= 150) begin
          fails++;
          $display("FAILED -- a=%0d b=%0d, both must exceed 150", nn.a, nn.b);
        end
      end
    end

    // ---- set-operator bounds are not truncated ----
    st = new();
    hi_x = 0; hi_z = 0; n = 0;
    for (int i = 0; i < 60; i++) begin
      if (!st.randomize()) begin
        fails++; $display("FAILED -- set-operator randomize() returned 0");
      end else begin
        n++;
        if (st.x > 44) hi_x++;
        if (st.z > 44) hi_z++;
        if (st.y < 200) begin
          fails++; $display("FAILED -- y=%0d below the [200:255] bound", st.y);
        end
      end
    end
    if (n > 0 && hi_x == 0) begin
      fails++;
      $display("FAILED -- `x inside {[0:300]}' acted as [0:44]: the bound truncated");
    end
    if (n > 0 && hi_z == 0) begin
      fails++;
      $display("FAILED -- `z dist {[0:300] := 1}' acted as [0:44]: the bound truncated");
    end

    // ---- a container member wider than the subject never matches ----
    // (it used to be masked down to the subject's width, so 300 became
    // a legal 44)
    ct = new();
    ct.tbl.push_back(300);
    ct.tbl.push_back(5);
    for (int i = 0; i < 20; i++) begin
      if (!ct.randomize()) begin
        fails++; $display("FAILED -- `x inside {tbl}' returned 0 with 5 in the table");
      end else if (ct.x !== 8'd5) begin
        fails++;
        $display("FAILED -- x=%0d; only 5 is reachable (300 does not fit 8 bits)", ct.x);
      end
    end

    // ---- a narrow variable times a wide literal ----
    m = new();
    for (int i = 0; i < 20; i++) begin
      if (!m.randomize()) begin
        fails++; $display("FAILED -- `big == n * 1000' reported UNSAT");
      end else begin
        if (m.big != (m.n * 1000)) begin
          fails++;
          $display("FAILED -- n=%0d big=%0d (want %0d)", m.n, m.big, m.n * 1000);
        end
        if (m.n <= 8) begin
          fails++; $display("FAILED -- n=%0d, must exceed 8", m.n);
        end
      end
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
