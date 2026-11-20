class positive_product;
  rand real a;
  constraint c { a * 2.0 inside {[2.0:4.0]}; }
endclass

class uniform_product;
  rand real a;
  constraint c { a * 2.0 inside {[0.0:4.0]}; }
endclass

class negative_product;
  rand real a;
  constraint c {
    -2.0 * a inside {[-4.0:-2.0]};
    soft a <= 1.75;
  }
endclass

class rounded_product;
  rand real a;
  constraint c {
    a * 0.5 inside {[0.0:0.0]};
    a > 0.0;
  }
endclass

class ordered_product;
  rand bit select_upper, selected;
  rand real a;
  constraint c {
    solve select_upper before a;
    solve a before selected;
    a * 2.0 inside {[2.0:4.0]};
    if (select_upper) a > 1.5;
    else a < 1.5;
    selected == select_upper;
  }
endclass

class empty_product;
  rand real a;
  constraint c { a * 2.0 inside {[4.9406564584124654e-324:4.9406564584124654e-324]}; }
endclass

module test;
  positive_product p;
  uniform_product u;
  negative_product n;
  rounded_product r;
  ordered_product o;
  empty_product e;
  int result, lower_count;
  longint unsigned previous;

  initial begin
    p = new;
    u = new;
    n = new;
    r = new;
    o = new;
    e = new;

    result = p.randomize();
    if (result != 1 || !(p.a >= 1.0 && p.a <= 2.0)
        || !(p.a * 2.0 inside {[2.0:4.0]}))
      $fatal(1, "positive product failed r=%0d a=%g", result, p.a);

    u.srandom(32'd3538);
    repeat (256) begin
      if (!u.randomize() || !(u.a * 2.0 inside {[0.0:4.0]}))
        $fatal(1, "uniform product range failed a=%g", u.a);
      if (u.a < 1.0) lower_count++;
    end
    if (lower_count < 96 || lower_count > 160)
      $fatal(1, "numeric halves were sampled unevenly (%0d/256)", lower_count);

    n.srandom(32'd3538);
    repeat (8) begin
      if (!n.randomize() with { a > 1.5; })
        $fatal(1, "negative product with inline bound failed");
      if (!(n.a > 1.5 && n.a <= 1.75) || !(-2.0 * n.a inside {[-4.0:-2.0]}))
        $fatal(1, "negative product or retained soft bound failed a=%g", n.a);
    end
    previous = $realtobits(n.a);
    if (n.randomize() with { a > 2.0; })
      $fatal(1, "contradictory product constraints unexpectedly solved");
    if ($realtobits(n.a) != previous)
      $fatal(1, "failed randomization changed the previous real value");

    result = r.randomize();
    if (result != 1 || $realtobits(r.a) != 64'h1
        || !(r.a * 0.5 inside {[0.0:0.0]}))
      $fatal(1, "rounded product preimage lost its least positive subnormal");

    o.srandom(32'd3538);
    repeat (4) begin
      if (!o.randomize() || !(o.a * 2.0 inside {[2.0:4.0]})
          || !(o.select_upper ? o.a > 1.5 : o.a < 1.5)
          || o.selected !== o.select_upper)
        $fatal(1, "solve-before product range or stage pin failed");
    end

    e.a = 1.0;
    result = e.randomize();
    if (result != 0 || e.a != 1.0)
      $fatal(1, "empty rounded preimage unexpectedly solved");

    $display("PASSED");
  end
endmodule
