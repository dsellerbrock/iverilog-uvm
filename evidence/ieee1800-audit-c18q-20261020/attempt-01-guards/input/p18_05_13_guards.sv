class D;
  int x;
endclass

class C1;
  rand int x, y;
  D a, b;
  constraint c1 { (x < y || a.x > b.x || a.x == 5) -> x + y == 10; }
endclass

class C2;
  rand int x, y;
  D a, b;
  constraint c1 { (x < y && a.x > b.x && a.x == 5) -> x + y == 10; }
endclass

module p18_05_13_guards;
  C1 c;
  C2 k;
  int rc, ok, bad, cond, uncond;

  task automatic run1(input string tag);
    ok = 0;
    bad = 0;
    cond = 0;
    uncond = 0;
    repeat (50) begin
      rc = c.randomize();
      ok += rc;
      if (rc) begin
        if (c.x + c.y == 10) uncond++;
        if (c.x < c.y && c.x + c.y != 10) bad++;
      end
    end
    $display("%s ok=%0d bad=%0d sum10=%0d", tag, ok, bad, uncond);
  endtask

  task automatic run2(input string tag);
    ok = 0;
    bad = 0;
    uncond = 0;
    repeat (50) begin
      rc = k.randomize();
      ok += rc;
      if (rc) begin
        if (k.x + k.y == 10) uncond++;
        if (k.x < k.y && k.x + k.y != 10) bad++;
      end
    end
    $display("%s ok=%0d bad=%0d sum10=%0d", tag, ok, bad, uncond);
  endtask

  initial begin
    c = new;
    k = new;
    c.a = new;
    c.b = null;
    c.a.x = 5;
    run1("E1C1");
    c.a = null;
    run1("E1C2");
    c.a = new;
    c.b = new;
    c.a.x = 10;
    c.b.x = 20;
    run1("E1C3");
    k.a = new;
    k.b = null;
    k.a.x = 6;
    run2("E2C1");
    k.a = null;
    run2("E2C2");
    k.a = new;
    k.b = new;
    k.a.x = 5;
    k.b.x = 2;
    run2("E2C3");
  end
endmodule
