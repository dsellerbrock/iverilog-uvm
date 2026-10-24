// IEEE 1800-2023 §18.5.4; IEEE 1800-2017 §18.4 rejects rand real.
module p18_05_4_unique_real_scalar;
  class R1; rand real r1, r2, r3;
    constraint d { r1 inside {1.0, 2.0, 3.0}; r2 inside {1.0, 2.0, 3.0}; r3 inside {1.0, 2.0, 3.0}; }
    constraint u { unique {r1, r2, r3}; } endclass
  class R1P; rand real r1, r2, r3, r4;
    constraint d { r1 inside {1.0, 2.0, 3.0}; r2 inside {1.0, 2.0, 3.0}; r3 inside {1.0, 2.0, 3.0}; r4 inside {1.0, 2.0, 3.0}; }
    constraint u { unique {r1, r2, r3, r4}; } endclass
  R1 a; R1P p; int ok = 0, bad = 0, rc;
  initial begin
    a = new; p = new;
    repeat (100) begin ok += a.randomize(); if (a.r1 == a.r2 || a.r1 == a.r3 || a.r2 == a.r3) bad++; end
    rc = p.randomize();
    $display("R1 ok=%0d bad=%0d R1P rc=%0d", ok, bad, rc);
  end
endmodule
