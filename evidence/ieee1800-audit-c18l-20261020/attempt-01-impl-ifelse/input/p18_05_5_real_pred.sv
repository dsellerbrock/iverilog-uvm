module p18_05_5_real_pred;
  class P1;
    real w;
    rand bit b;
    constraint k { w -> (b == 1); }
  endclass
  class P2;
    rand real r;
    rand bit b;
    constraint d { r >= 0.0; r <= 1.0; }
    constraint k { if (r) b == 1; else b == 0; }
  endclass
  P1 p1;
  P2 p2;
  int bad, rc, b0, b1;
  initial begin
    p1 = new;
    p2 = new;
    p1.w = 0.5;
    bad = 0;
    repeat (100) begin
      rc = p1.randomize();
      if (!rc || p1.b != 1) bad++;
    end
    $display("P1_W05 bad=%0d", bad);

    p1.w = 0.0;
    bad = 0;
    b0 = 0;
    b1 = 0;
    repeat (200) begin
      rc = p1.randomize();
      if (!rc) bad++;
      else if (p1.b == 0) b0++;
      else b1++;
    end
    $display("P1_W0 fail=%0d", bad);
    $display("P1_W0 b0=%0d b1=%0d", b0, b1);

    bad = 0;
    repeat (100) begin
      rc = p2.randomize() with { r == 0.5; };
      if (!rc || p2.b != 1) bad++;
    end
    $display("P2_R05 bad=%0d", bad);

    bad = 0;
    repeat (100) begin
      rc = p2.randomize() with { r == 0.0; };
      if (!rc || p2.b != 0) bad++;
    end
    $display("P2_R0 bad=%0d", bad);

    bad = 0;
    repeat (100) begin
      rc = p2.randomize() with { b == 0; };
      if (!rc || p2.r != 0.0) bad++;
    end
    $display("P2_BIDIR bad=%0d", bad);
  end
endmodule
