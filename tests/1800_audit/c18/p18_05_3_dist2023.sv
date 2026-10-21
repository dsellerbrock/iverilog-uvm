module p18_05_3_dist2023;
  class E1; rand int x; constraint c { x dist {[100:102] := 1, 101 := 1}; } endclass
  class E2; rand int x; constraint c { x dist {100 :/ 0, [100:102] :/ 1}; } endclass
  class E3; rand int x; constraint c { x > 101; x dist {[100:102] := 1, 103 := 1}; } endclass
  class E6; rand int x; constraint c { soft x dist {1 := 1, 2 := 1}; } endclass

  int h[int];
  E1 e1; E2 e2; E3 e3; E6 e6;
  int selected;
  int ok;

  task automatic show(string tag, int keys[$]);
    int other;
    bit found;
    other = 0;
    foreach (h[k]) begin
      found = 0;
      foreach (keys[i])
        if (keys[i] == k) found = 1;
      if (!found) other += h[k];
    end
    $write("%s", tag);
    foreach (keys[i])
      $write(" %0d:%0d", keys[i], h.exists(keys[i]) ? h[keys[i]] : 0);
    $display(" other=%0d", other);
  endtask

  initial begin
    e1 = new; e2 = new; e3 = new; e6 = new;
    if (!$value$plusargs("CASE=%d", selected)) selected = 0;
    if (selected == 0 || selected == 1) begin
      h.delete(); repeat (8000) begin void'(e1.randomize()); h[e1.x]++; end
      show("E1", '{100,101,102});
    end
    if (selected == 0 || selected == 2) begin
      h.delete(); repeat (6000) begin void'(e2.randomize()); h[e2.x]++; end
      show("E2", '{100,101,102});
    end
    if (selected == 0 || selected == 3) begin
      h.delete(); repeat (8000) begin void'(e3.randomize()); h[e3.x]++; end
      show("E3", '{102,103});
    end
    if (selected == 0 || selected == 4) begin
      ok = e6.randomize() with { x == 5; };
      $display("E6 rc=%0d x=%0d", ok, e6.x);
    end
  end
endmodule
