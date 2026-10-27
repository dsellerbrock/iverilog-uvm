// IEEE 1800-2017 §§18.5.6–18.5.7; IEEE 1800-2023 §§18.5.5–18.5.6.
module p18_05_6_impl_ifelse;
  class I1;
    rand bit [1:0] a, b;
    constraint c { (a == 0) -> (b == 1); }
  endclass
  class I2;
    rand bit [1:0] a;
    rand bit [3:0] b, c;
    constraint k { (a == 0) -> { b == 1; c == 2; } }
  endclass
  class F1;
    rand bit [1:0] mode;
    rand bit [7:0] len;
    constraint k { if (mode == 0) len < 10; else if (mode == 1) len > 100; }
  endclass
  class F2;
    rand bit [1:0] mode;
    rand bit [7:0] len;
    constraint k { if (mode != 1) if (mode == 0) len < 10; else len > 100; }
  endclass
  class F3;
    rand bit a;
    rand bit [3:0] x, y;
    constraint k { if (a) { x == 1; y == 2; } else { x == 3; } }
  endclass

  I1 i1;
  I2 i2;
  F1 f1;
  F2 f2;
  F3 f3;
  int a0, bad, m1_free, rc;

  initial begin
    i1 = new;
    i2 = new;
    f1 = new;
    f2 = new;
    f3 = new;
    a0 = 0;
    bad = 0;
    repeat (4000) begin
      void'(i1.randomize());
      if (i1.a == 0) begin a0++; if (i1.b != 1) bad++; end
    end
    $display("I1 a0=%0d bad=%0d", a0, bad);

    bad = 0;
    repeat (200) begin
      rc = i1.randomize() with { b == 0; };
      if (!rc || i1.a == 0) bad++;
    end
    $display("I1_BIDIR bad=%0d", bad);

    bad = 0;
    repeat (500) begin
      void'(i2.randomize());
      if (i2.a == 0 && (i2.b != 1 || i2.c != 2)) bad++;
    end
    $display("I2 bad=%0d", bad);

    bad = 0;
    repeat (1000) begin
      void'(f1.randomize());
      if ((f1.mode == 0 && f1.len >= 10) || (f1.mode == 1 && f1.len <= 100)) bad++;
    end
    $display("F1 bad=%0d", bad);

    bad = 0;
    repeat (200) begin
      rc = f1.randomize() with { len == 50; };
      if (!rc || f1.mode < 2) bad++;
    end
    $display("F1_BIDIR bad=%0d", bad);

    bad = 0;
    m1_free = 0;
    repeat (1000) begin
      void'(f2.randomize());
      if ((f2.mode == 0 && f2.len >= 10) || (f2.mode >= 2 && f2.len <= 100)) bad++;
      if (f2.mode == 1 && f2.len <= 100) m1_free++;
    end
    $display("F2 bad=%0d m1_free=%0d", bad, m1_free);

    bad = 0;
    repeat (500) begin
      void'(f3.randomize());
      if ((f3.a && (f3.x != 1 || f3.y != 2)) || (!f3.a && f3.x != 3)) bad++;
    end
    $display("F3 bad=%0d", bad);
  end
endmodule
