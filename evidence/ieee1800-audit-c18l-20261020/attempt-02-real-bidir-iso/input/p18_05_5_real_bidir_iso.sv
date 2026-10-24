module p18_05_5_real_bidir_iso;
  class B0;
    rand real r;
    rand bit b;
    constraint d { r >= 0.0; r <= 1.0; }
  endclass
  class B4 extends B0;
    constraint k { (r) -> (b == 1); }
  endclass
  class B5 extends B0;
    constraint k { if (r != 0.0) b == 1; else b == 0; }
  endclass
  B0 o;
  B4 o4;
  B5 o5;
  int ok, bad, rc;
  initial begin
    o = new; o4 = new; o5 = new;
    ok = 0; bad = 0;
    repeat (5) begin
      rc = o.randomize() with { r == 0.0 || r == 1.0; };
      ok += rc;
      if (rc && !(o.r == 0.0 || o.r == 1.0)) bad++;
    end
    $display("D1 ok=%0d bad=%0d", ok, bad);
    ok = 0; bad = 0;
    repeat (5) begin
      rc = o.randomize() with { !(r != 0.0); };
      ok += rc;
      if (rc && o.r != 0.0) bad++;
    end
    $display("D2 ok=%0d bad=%0d", ok, bad);
    ok = 0; bad = 0;
    repeat (5) begin
      rc = o.randomize() with { !r; };
      ok += rc;
      if (rc && o.r != 0.0) bad++;
    end
    $display("D3 ok=%0d bad=%0d", ok, bad);
    ok = 0; bad = 0;
    repeat (5) begin
      rc = o4.randomize() with { b == 0; };
      ok += rc;
      if (rc && o4.r != 0.0) bad++;
    end
    $display("D4 ok=%0d bad=%0d", ok, bad);
    ok = 0; bad = 0;
    repeat (5) begin
      rc = o5.randomize() with { b == 0; };
      ok += rc;
      if (rc && o5.r != 0.0) bad++;
    end
    $display("D5 ok=%0d bad=%0d", ok, bad);
  end
endmodule
