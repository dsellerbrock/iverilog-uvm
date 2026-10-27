class D;
  int x;
endclass

class C1;
  rand int x, y;
  D a, b;
  constraint c1 { (x < y || a.x > b.x || a.x == 5) -> x + y == 10; }
endclass

module p18_05_13_error_order;
  C1 c;
  int rc, ok, bad, sum10;

  task automatic run_case(input string tag);
    ok = 0;
    bad = 0;
    sum10 = 0;
    repeat (50) begin
      rc = c.randomize();
      ok += rc;
      if (rc) begin
        if (c.x + c.y == 10) sum10++;
        if (c.x < c.y && c.x + c.y != 10) bad++;
      end
    end
    $display("%s ok=%0d bad=%0d sum10=%0d", tag, ok, bad, sum10);
    $fflush;
  endtask

  initial begin
    c = new;
    $display("BEGIN E1C1"); $fflush;
    c.a = new; c.b = null; c.a.x = 5;
    run_case("E1C1");
    $display("BEGIN E1C2"); $fflush;
    c.a = null;
    run_case("E1C2");
    $display("BEGIN E1C3"); $fflush;
    c.a = new; c.b = new; c.a.x = 10; c.b.x = 20;
    run_case("E1C3");
    $display("END E1C3"); $fflush;
  end
endmodule
