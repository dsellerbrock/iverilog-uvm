// IEEE 1800-2023 §18.5.4; IEEE 1800-2017 §18.4 rejects rand real.
module p18_05_4_unique_real_scalar;
  class R1; rand real r1, r2, r3;
    constraint d { r1 inside {1.0, 2.0, 3.0}; r2 inside {1.0, 2.0, 3.0}; r3 inside {1.0, 2.0, 3.0}; }
    constraint u { unique {r1, r2, r3}; } endclass
  class R1P; rand real r1, r2, r3, r4;
    constraint d { r1 inside {1.0, 2.0, 3.0}; r2 inside {1.0, 2.0, 3.0}; r3 inside {1.0, 2.0, 3.0}; r4 inside {1.0, 2.0, 3.0}; }
    constraint u { unique {r1, r2, r3, r4}; } endclass
  class C0; rand real r; constraint d { r inside {1.0, 2.0, 3.0}; } endclass
  class C1; rand real r; constraint d { r >= 1.0; r <= 3.0; } endclass
  class C2; rand real r1, r2;
    constraint d { r1 >= 1.0; r1 <= 3.0; r2 >= 1.0; r2 <= 3.0; }
    constraint u { unique {r1, r2}; } endclass
  class C3; rand real r1, r2;
    constraint d { r1 inside {1.0, 2.0}; r2 inside {1.0, 2.0}; r1 != r2; } endclass
  R1 a; R1P p; C0 c0; C1 c1; C2 c2; C3 c3;
  int ok = 0, bad = 0, ok0 = 0, bad0 = 0, ok1 = 0, bad1 = 0;
  int ok2 = 0, bad2 = 0, ok3 = 0, bad3 = 0, rc;
  initial begin
    a = new; p = new; c0 = new; c1 = new; c2 = new; c3 = new;
    repeat (100) begin
      if (a.randomize()) begin ok++; if (a.r1 == a.r2 || a.r1 == a.r3 || a.r2 == a.r3) bad++; end
      if (c0.randomize()) begin ok0++; if (c0.r != 1.0 && c0.r != 2.0 && c0.r != 3.0) bad0++; end
      if (c1.randomize()) begin ok1++; if (c1.r < 1.0 || c1.r > 3.0) bad1++; end
      if (c2.randomize()) begin ok2++; if (c2.r1 == c2.r2) bad2++; end
      if (c3.randomize()) begin ok3++; if (c3.r1 == c3.r2) bad3++; end
    end
    rc = p.randomize();
    $display("R1 ok=%0d bad=%0d R1P rc=%0d C0 ok=%0d bad=%0d", ok, bad, rc, ok0, bad0);
    $display("C1 ok=%0d bad=%0d C2 ok=%0d bad=%0d C3 ok=%0d bad=%0d", ok1, bad1, ok2, bad2, ok3, bad3);
  end
endmodule
