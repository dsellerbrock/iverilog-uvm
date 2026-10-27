// IEEE 1800-2023 §18.5.4; IEEE 1800-2017 §18.4 rejects rand real.
module p18_05_4_unique_real_scalar;
  class R1;
    rand real r1, r2, r3;
    constraint d {
      r1 inside {1.0, 2.0, 3.0};
      r2 inside {1.0, 2.0, 3.0};
      r3 inside {1.0, 2.0, 3.0};
    }
    constraint u { unique {r1, r2, r3}; }
  endclass

  initial begin
    R1 a;
    int ok1, bad1;
    ok1 = 0;
    bad1 = 0;
    a = new;
    repeat (100) begin
      ok1 += a.randomize();
      if (a.r1 == a.r2 || a.r1 == a.r3 || a.r2 == a.r3) bad1++;
    end
    $display("R1_SCALAR ok=%0d bad=%0d", ok1, bad1);
  end
endmodule
