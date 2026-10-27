module p18_05_4_dist;
  class D1; rand int x; constraint c { x dist {100 := 1, 200 := 2, 300 := 5}; } endclass
  class D2; rand int x; constraint c { x != 200; x dist {100 := 1, 200 := 2, 300 := 5}; } endclass
  class D3; rand int x; constraint c { x dist {[100:102] := 1, 200 := 2, 300 := 5}; } endclass
  class D4; rand int x; constraint c { x dist {[100:102] :/ 1, 200 := 2, 300 := 5}; } endclass
  class D5; rand int x; constraint c { x dist {1 := 0, 2 := 1}; } endclass
  class D6; rand int x; int w = 3; constraint c { x dist {1 := w, 2 := 1}; } endclass
  class D7; rand int x; constraint c { x dist {1 := 1, 2 := 1}; } endclass

  int h[int];
  D1 d1; D2 d2; D3 d3; D4 d4; D5 d5; D6 d6; D7 d7;
  int ok;
  int selected;

  task automatic show(string tag, int keys[$]);
    int other;
    bit found;
    other = 0;
    $write("%s", tag);
    foreach (keys[i])
      $write(" %0d:%0d", keys[i], h.exists(keys[i]) ? h[keys[i]] : 0);
    foreach (h[k]) begin
      found = 0;
      foreach (keys[i])
        if (keys[i] == k) found = 1;
      if (!found) other++;
    end
    $display(" other=%0d", other);
  endtask

  initial begin
    d1 = new; d2 = new; d3 = new; d4 = new;
    d5 = new; d6 = new; d7 = new;
    if (!$value$plusargs("CASE=%d", selected)) selected = 0;
    if (selected == 0 || selected == 1) begin
      h.delete(); repeat (8000) begin void'(d1.randomize()); h[d1.x]++; end show("D1", '{100,200,300});
    end
    if (selected == 0 || selected == 2) begin
      h.delete(); repeat (6000) begin void'(d2.randomize()); h[d2.x]++; end show("D2", '{100,200,300});
    end
    if (selected == 0 || selected == 3) begin
      h.delete(); repeat (10000) begin void'(d3.randomize()); h[d3.x]++; end show("D3", '{100,101,102,200,300});
    end
    if (selected == 0 || selected == 4) begin
      h.delete(); repeat (9000) begin void'(d4.randomize()); h[d4.x]++; end show("D4", '{100,101,102,200,300});
    end
    if (selected == 0 || selected == 5) begin
      h.delete(); repeat (400) begin void'(d5.randomize()); h[d5.x]++; end show("D5", '{1,2});
    end
    if (selected == 0 || selected == 6) begin
      h.delete(); repeat (4000) begin void'(d6.randomize()); h[d6.x]++; end show("D6", '{1,2});
    end
    if (selected == 0 || selected == 7) begin
      ok = d7.randomize() with { x == 5; };
      $display("D7 rc=%0d", ok);
    end
  end
endmodule
