function automatic int count_ones(bit [9:0] w);
  count_ones = 0;
  for (; w != 0; w = w >> 1) count_ones += w & 1'b1;
endfunction

function automatic int cr(const ref bit [9:0] w);
  return w[0];
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

class F3;
  rand bit [9:0] v;
  rand bit b;
  constraint c { b == cr(v); }
endclass

module p18_05_12_func;
  F1 f1;
  F2 f2;
  F3 f3;
  int bad, ok;
  initial begin
    f1 = new;
    f2 = new;
    f3 = new;
    bad = 0;
    repeat (200) begin
      if (!f1.randomize() || f1.length != count_ones(f1.v)) bad++;
    end
    $display("F1 bad=%0d", bad);
    ok = 0;
    bad = 0;
    repeat (200) begin
      if (f2.randomize()) begin
        ok++;
        if (f2.length != count_ones(f2.v) || f2.length >= 3) bad++;
      end
    end
    $display("F2 ok=%0d bad=%0d", ok, bad);
    bad = 0;
    repeat (100) begin
      if (!f3.randomize() || f3.b != f3.v[0]) bad++;
    end
    $display("F3 bad=%0d", bad);
  end
endmodule
