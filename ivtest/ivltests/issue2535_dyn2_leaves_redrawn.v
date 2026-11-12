// Issue #2535: the leaves of a rand dynamic array of dynamic arrays are
// rand. IEEE 1800-2023 18.4: "Arrays can be declared rand or randc, in
// which case all of their member elements are treated as rand or randc."
// Each class pre-sets w[0][0] = 9 and is randomized over 40 seeds. A 4-bit
// leaf keeps 9 by chance about 1 time in 16; it must not be kept every time.
module top;
  typedef enum bit [1:0] { RED, GREEN, BLUE } color_t;

  class named;   // leaves named by a constraint
    rand bit [3:0] w[][];
    constraint c { w.size == 2; foreach (w[i, j]) w[i][j] < 15; }
  endclass
  class sizes;   // only the inner sizes named
    rand bit [3:0] w[][];
    constraint c { w.size == 2; foreach (w[i]) w[i].size() == 1; }
  endclass
  class none;    // nothing named: the sizes are kept, the leaves redrawn
    rand bit [3:0] w[][];
  endclass
  class colors;  // enum leaves stay in their domain
    rand color_t w[][];
  endclass
  class frozen;  // rand_mode(0) keeps them
    rand bit [3:0] w[][];
  endclass

  named x1 = new;
  sizes x2 = new;
  none x3 = new;
  colors x4 = new;
  frozen x5 = new;
  int k1, k2, k3, bad = 0;
  bit seen_green = 0, seen_blue = 0;

  initial begin
    x5.w.rand_mode(0);
    for (int s = 1; s <= 40; s++) begin
      x1.srandom(s); x2.srandom(s); x3.srandom(s); x4.srandom(s);
      x1.w = new[1]; x1.w[0] = new[1]; x1.w[0][0] = 4'h9;
      x2.w = new[1]; x2.w[0] = new[1]; x2.w[0][0] = 4'h9;
      x3.w = new[1]; x3.w[0] = new[1]; x3.w[0][0] = 4'h9;
      x4.w = new[1]; x4.w[0] = new[2]; x4.w[0][0] = RED; x4.w[0][1] = RED;
      x5.w = new[1]; x5.w[0] = new[1]; x5.w[0][0] = 4'h9;
      if (!x1.randomize() || !x2.randomize() || !x3.randomize()
          || !x4.randomize() || !x5.randomize()) bad++;
      k1 += x1.w[0][0] == 4'h9;
      k2 += x2.w[0][0] == 4'h9;
      k3 += x3.w[0][0] == 4'h9;
      if (x1.w.size() != 2 || x1.w[0][0] >= 15) bad++;
      if (x3.w.size() != 1 || x3.w[0].size() != 1) bad++;
      foreach (x4.w[i, j]) begin
        if (x4.w[i][j] > BLUE) bad++;
        if (x4.w[i][j] == GREEN) seen_green = 1;
        if (x4.w[i][j] == BLUE) seen_blue = 1;
      end
      if (x5.w[0][0] != 4'h9) bad++;
    end
    // About 2.5 of 40 expected; keeping it in more than 10 is not random.
    if (k1 > 10 || k2 > 10 || k3 > 10 || !seen_green || !seen_blue) bad++;
    if (bad == 0) $display("PASSED");
    else $display("FAILED: bad=%0d kept named=%0d sizes=%0d none=%0d", bad, k1, k2, k3);
  end
endmodule
