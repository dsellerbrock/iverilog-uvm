module p18_05_4_dist;
  class D1; rand int x; constraint c { x dist {100 := 1, 200 := 2, 300 := 5}; } endclass
  class D2; rand int x; constraint c { x != 200; x dist {100 := 1, 200 := 2, 300 := 5}; } endclass
  class D3; rand int x; constraint c { x dist {[100:102] := 1, 200 := 2, 300 := 5}; } endclass
  class D4; rand int x; constraint c { x dist {[100:102] :/ 1, 200 := 2, 300 := 5}; } endclass
  class D5; rand int x; constraint c { x dist {1 := 0, 2 := 1}; } endclass
  class D6; rand int x; int w = 3; constraint c { x dist {1 := w, 2 := 1}; } endclass
  class D7; rand int x; constraint c { x dist {1 := 1, 2 := 1}; } endclass

  int h[int];

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
    D1 d1 = new; D2 d2 = new; D3 d3 = new; D4 d4 = new;
    D5 d5 = new; D6 d6 = new; D7 d7 = new;
    int ok;
    h.delete(); repeat (8000)  begin void'(d1.randomize()); h[d1.x]++; end show("D1", '{100,200,300});
    h.delete(); repeat (6000)  begin void'(d2.randomize()); h[d2.x]++; end show("D2", '{100,200,300});
    h.delete(); repeat (10000) begin void'(d3.randomize()); h[d3.x]++; end show("D3", '{100,101,102,200,300});
    h.delete(); repeat (9000)  begin void'(d4.randomize()); h[d4.x]++; end show("D4", '{100,101,102,200,300});
    h.delete(); repeat (400)   begin void'(d5.randomize()); h[d5.x]++; end show("D5", '{1,2});
    h.delete(); repeat (4000)  begin void'(d6.randomize()); h[d6.x]++; end show("D6", '{1,2});
    ok = d7.randomize() with { x == 5; };
    $display("D7 rc=%0d", ok);
  end
endmodule
