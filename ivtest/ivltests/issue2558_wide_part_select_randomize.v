class issue2558_a;
  rand bit [65:0] v;
  constraint c { v[15:0] == 7; }
endclass

class issue2558_b;
  rand bit [65:0] v;
  constraint c { v[33:0] == 34'h2_0000_0003; }
endclass

class issue2558_d;
  rand bit [127:0] v;
  constraint c { v[70:60] == 11'h5a5; }
endclass

class issue2558_n;
  rand bit [63:0] v;
  constraint c { v[15:0] == 7; }
endclass

module main;
  issue2558_a a = new;
  issue2558_b b = new;
  issue2558_d d = new;
  issue2558_n n = new;

  initial begin
    if (!a.randomize() || a.v[15:0] != 16'h0007)
      $fatal(1, "66-bit low part-select failed: %h", a.v[15:0]);
    if (!b.randomize() || b.v[33:0] != 34'h2_0000_0003)
      $fatal(1, "66-bit wide part-select failed: %h", b.v[33:0]);
    if (!d.randomize() || d.v[70:60] != 11'h5a5)
      $fatal(1, "128-bit middle part-select failed: %h", d.v[70:60]);
    if (!n.randomize() || n.v[15:0] != 16'h0007)
      $fatal(1, "64-bit low part-select failed: %h", n.v[15:0]);
    $display("ISSUE2558 part-select randomization PASS");
  end
endmodule
