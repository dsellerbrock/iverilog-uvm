// IEEE 1800-2023 §18.5.4; IEEE 1800-2017 §18.5.5 rejects rand real at §18.4.
module p18_05_4_unique_real;
  class R1;
    rand real r1, r2, r3;
    constraint d {
      r1 inside {1.0, 2.0, 3.0};
      r2 inside {1.0, 2.0, 3.0};
      r3 inside {1.0, 2.0, 3.0};
    }
    constraint u { unique {r1, r2, r3}; }
  endclass
  class R2;
    rand real ra[3];
    constraint d { foreach (ra[i]) ra[i] inside {1.0, 2.0, 3.0}; }
    constraint u { unique {ra}; }
  endclass
  class R3;
    rand real ra[4];
    constraint d { foreach (ra[i]) ra[i] inside {1.0, 2.0, 3.0}; }
    constraint u { unique {ra}; }
  endclass

  initial begin
    R1 a;
    R2 b;
    R3 c;
    int ok1, bad1, ok2, bad2, rc;

    ok1 = 0;
    bad1 = 0;
    ok2 = 0;
    bad2 = 0;
    a = new;
    b = new;
    c = new;
    repeat (100) begin
      ok1 += a.randomize();
      if (a.r1 == a.r2 || a.r1 == a.r3 || a.r2 == a.r3) bad1++;
      ok2 += b.randomize();
      if (b.ra[0] == b.ra[1] || b.ra[0] == b.ra[2] || b.ra[1] == b.ra[2]) bad2++;
    end
    rc = c.randomize();
    $display("R1 ok=%0d bad=%0d R2 ok=%0d bad=%0d R3 rc=%0d", ok1, bad1, ok2, bad2, rc);
  end
endmodule
