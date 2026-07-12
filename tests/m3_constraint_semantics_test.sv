// M3 constraint regression: implication, if-else, enum inside, inheritance
// (IEEE 1800-2017 Ch. 18 constraint blocks).
module m3_constraint_semantics_test;
  typedef enum { RED, GREEN, BLUE, YELLOW, MAGENTA } color_t;

  class ImplC;                       // G15: implication
    rand int unsigned x;
    rand int unsigned y;
    constraint c { x < 2; (x == 0) -> (y == 99); (x != 0) -> (y == 7); }
  endclass

  class IfC;                         // G17: if-else constraint set
    rand int unsigned m;
    rand int unsigned v;
    constraint c {
      m < 2;
      if (m == 1) { v inside {[100:200]}; }
      else        { v inside {[1:5]}; }
    }
  endclass

  class EnumC;                       // G18: inside over enum literals
    rand color_t col;
    constraint c { col inside {RED, BLUE, MAGENTA}; }
  endclass

  class Par;                         // G20: inherited constraints
    rand int unsigned x;
    constraint cp { x inside {[1:50]}; }
  endclass
  class Chi extends Par;
    rand int unsigned y;
    constraint cc { y == x * 2; }
  endclass

  class SolveC;                      // G11: solve-before + implication
    rand bit a;
    rand int unsigned b;
    constraint c { solve a before b; a -> b == 100; (!a) -> b == 0; }
  endclass

  initial begin
    ImplC ic = new;
    IfC   fc = new;
    EnumC ec = new;
    Chi   ch = new;
    SolveC sc = new;
    int errors = 0;
    int a0, a1;

    repeat (20) begin
      void'(ic.randomize());
      if (!((ic.x == 0 && ic.y == 99) || (ic.x == 1 && ic.y == 7))) begin
        $display("FAIL impl x=%0d y=%0d", ic.x, ic.y);
        errors++;
      end
      void'(fc.randomize());
      if (!((fc.m == 1 && fc.v >= 100 && fc.v <= 200)
            || (fc.m == 0 && fc.v >= 1 && fc.v <= 5))) begin
        $display("FAIL ifelse m=%0d v=%0d", fc.m, fc.v);
        errors++;
      end
      void'(ec.randomize());
      if (!(ec.col inside {RED, BLUE, MAGENTA})) begin
        $display("FAIL enum col=%0d", ec.col);
        errors++;
      end
      void'(ch.randomize());
      if (!(ch.x >= 1 && ch.x <= 50 && ch.y == ch.x * 2)) begin
        $display("FAIL inherit x=%0d y=%0d", ch.x, ch.y);
        errors++;
      end
      void'(sc.randomize());
      if (!((sc.a == 1 && sc.b == 100) || (sc.a == 0 && sc.b == 0))) begin
        $display("FAIL solve a=%0d b=%0d", sc.a, sc.b);
        errors++;
      end
      if (sc.a) a1++; else a0++;
    end

    // solve-before should give both a-values a fair share (soft check).
    if (a0 == 0 || a1 == 0)
      $display("WARN solve-before distribution a0=%0d a1=%0d", a0, a1);

    if (errors == 0) $display("PASS");
    else $display("TOTAL FAILS: %0d", errors);
  end
endmodule
