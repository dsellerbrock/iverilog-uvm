class table18_2_unordered;
  rand bit s;
  rand bit [31:0] d;
  constraint c { s -> d == 0; }
endclass
class small_dom;
  rand bit [3:0] a, b;
  constraint c { a < b; a + b == 10; }
endclass
module main;
  initial begin
    table18_2_unordered t = new;
    small_dom sd = new;
    int ones = 0, hist[16];
    for (int i = 0; i < 400; i++) begin
      if (!t.randomize()) $display("FAIL");
      ones += t.s;
    end
    for (int i = 0; i < 400; i++) begin
      if (!sd.randomize()) $display("FAIL2");
      hist[sd.a]++;
    end
    $display("ones=%0d a0=%0d a1=%0d a2=%0d a3=%0d a4=%0d", ones, hist[0], hist[1], hist[2], hist[3], hist[4]);
  end
endmodule
