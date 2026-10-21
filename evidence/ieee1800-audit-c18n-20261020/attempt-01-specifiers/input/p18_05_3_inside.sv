class S1; rand bit [3:0] x; constraint c { x inside {3, 5, [9:15]}; } endclass
class S2; rand bit [3:0] x; constraint c { !(x inside {[0:13]}); } endclass
class S3; rand bit [3:0] x, y; constraint c { x inside {[y:2*y]}; } endclass

module p18_05_3_inside;
  S1 s1;
  S2 s2;
  S3 s3;
  int h[int];
  int bad;
  initial begin
    s1 = new;
    s2 = new;
    s3 = new;
    repeat (4500) begin
      void'(s1.randomize());
      h[s1.x]++;
    end
    foreach (h[k]) $write("%0d:%0d ", k, h[k]);
    $display("S1");
    bad = 0;
    repeat (200) begin
      void'(s2.randomize());
      if (!(s2.x inside {14, 15})) bad++;
    end
    $display("S2 bad=%0d", bad);
    bad = 0;
    repeat (200) begin
      if (!s3.randomize() with { y == 3; }) bad++;
      else if (!(s3.x inside {[3:6]})) bad++;
    end
    $display("S3 bad=%0d", bad);
  end
endmodule
