function automatic int count_ones(bit [9:0] w);
  count_ones = 0;
  for (; w != 0; w = w >> 1) count_ones += w & 1'b1;
endfunction

class F1;
  rand bit [9:0] v;
  rand bit [3:0] length;
  constraint c1 { length == count_ones(v); }
endclass

class F2;
  rand bit [9:0] v;
  rand bit [3:0] length;
  constraint c1 { length == count_ones(v); length < 3; }
endclass

class F4;
  rand bit [9:0] v;
  rand bit [3:0] length;
  constraint c1 { length == count_ones(v); }
  constraint c2 { length < 3; }
endclass

module p18_05_12_f2diag;
  F1 f1;
  F2 f2;
  F4 f4;
  int i, rc, lowpop, ok, bad;
  initial begin
    f1 = new;
    f2 = new;
    f4 = new;

    lowpop = 0;
    repeat (400) begin
      if (!f1.randomize()) $fatal(1, "D0 randomize failed");
      if (count_ones(f1.v) < 3) lowpop++;
    end
    $display("D0 lowpop=%0d", lowpop);

    rc = f2.randomize() with { v == 10'b0000000011; };
    $display("D1 rc=%0d v=%b len=%0d", rc, f2.v, f2.length);
    rc = f2.randomize() with { v == 10'h3FF; };
    $display("D2 rc=%0d v=%b len=%0d", rc, f2.v, f2.length);

    for (i = 0; i < 20; i++) begin
      rc = f2.randomize();
      $display("D3 i=%0d rc=%0d v=%b pop=%0d len=%0d", i, rc, f2.v,
               count_ones(f2.v), f2.length);
    end

    ok = 0;
    bad = 0;
    repeat (200) begin
      if (f4.randomize()) begin
        ok++;
        if (f4.length != count_ones(f4.v) || f4.length >= 3) bad++;
      end
    end
    $display("D4 ok=%0d bad=%0d", ok, bad);
  end
endmodule
