module p18_05_1_extern_inherit;
  class C;
    rand bit [3:0] x, y;
    constraint p1;
    extern constraint p2;
    constraint p3;
  endclass
  constraint C::p1 { x inside {1,5,7}; }
  constraint C::p2 { y >= 12; }

  class B;
    rand bit [3:0] v;
    constraint c1 { v < 4; }
    constraint c2 { v[0] == 0; }
  endclass
  class D extends B;
    constraint c1 { v > 10; }
  endclass
  class E extends B;
    constraint c1;
  endclass
  constraint E::c1 { v == 8; }

  virtual class V;
    rand bit [3:0] w;
    pure constraint t;
  endclass
  class W extends V;
    constraint t { w == 3; }
  endclass

  C c;
  B b, bh;
  D d_obj;
  E e;
  W w;
  int ok, bad, n12, n14, rc;
  initial begin
    c = new;
    ok=0; bad=0;
    repeat (50) begin
      rc=c.randomize();
      if (rc) begin ok++; if (!(c.x inside {1,5,7}) || c.y < 12) bad++; end
    end
    $display("C ok=%0d bad=%0d", ok, bad);
    ok=0;
    repeat (50) begin if (c.randomize()) ok++; end
    $display("C_P3 ok=%0d", ok);

    b = new;
    ok=0; bad=0;
    repeat (50) begin
      rc=b.randomize();
      if (rc) begin ok++; if (!(b.v inside {0,2})) bad++; end
    end
    $display("B ok=%0d bad=%0d", ok, bad);

    d_obj = new;
    ok=0; bad=0; n12=0; n14=0;
    repeat (50) begin
      rc=d_obj.randomize();
      if (rc) begin
        ok++;
        if (!(d_obj.v inside {12,14})) bad++;
        if (d_obj.v == 12) n12++;
        if (d_obj.v == 14) n14++;
      end
    end
    $display("D ok=%0d bad=%0d n12=%0d n14=%0d", ok, bad, n12, n14);

    bh = d_obj;
    ok=0; bad=0; n12=0; n14=0;
    repeat (50) begin
      rc=bh.randomize();
      if (rc) begin
        ok++;
        if (!(d_obj.v inside {12,14})) bad++;
        if (d_obj.v == 12) n12++;
        if (d_obj.v == 14) n14++;
      end
    end
    $display("DV ok=%0d bad=%0d n12=%0d n14=%0d", ok, bad, n12, n14);

    e = new;
    ok=0; bad=0;
    repeat (50) begin
      rc=e.randomize();
      if (rc) begin ok++; if (e.v != 8) bad++; end
    end
    $display("E ok=%0d bad=%0d", ok, bad);

    w = new;
    ok=0; bad=0;
    repeat (50) begin
      rc=w.randomize();
      if (rc) begin ok++; if (w.w != 3) bad++; end
    end
    $display("W ok=%0d bad=%0d", ok, bad);
  end
endmodule
