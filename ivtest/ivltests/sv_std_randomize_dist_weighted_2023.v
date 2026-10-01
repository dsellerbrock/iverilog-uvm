// std::randomize(v) with { v dist { ... } } is a weighted random draw
// (IEEE 1800-2017/2023 18.5.4, 18.12), not an optimization target: it always
// returned the heaviest value, so `dist { 1 := 1, 2 := 2, 3 := 1 }' gave 2
// every time.
module main;
  int errors;
  initial begin
    int unsigned v;
    int c1, c2, c3, ok;
    repeat (400) begin
      ok = std::randomize(v) with { v dist { 1 := 1, 2 := 2, 3 := 1 }; };
      if (!ok) begin $display("FAILED randomize"); errors++; end
      case (v) 1: c1++; 2: c2++; 3: c3++; default: begin $display("FAILED v=%0d", v); errors++; end endcase
    end
    // Expected 100/200/100; each bound is about 4.5 sigma wide.
    if (c1 < 55 || c1 > 145 || c3 < 55 || c3 > 145 || c2 < 150 || c2 > 250) begin
      $display("FAILED split %0d/%0d/%0d", c1, c2, c3); errors++;
    end
    c1 = 0; c2 = 0; c3 = 0;
    repeat (400) begin
      ok = std::randomize(v) with { v dist { 1 := 1, 2 := 5, 3 := 2 }; v != 2; };
      case (v) 1: c1++; 3: c3++; default: begin $display("FAILED v=%0d", v); errors++; end endcase
    end
    // v == 2 is infeasible and its weight drops out (18.5.4): 1 carries 1 of
    // the remaining 3 shares, 3 carries 2. Expected 133/267.
    if (c1 < 80 || c1 > 190 || c3 < 210 || c3 > 320) begin
      $display("FAILED split2 %0d/%0d", c1, c3); errors++;
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
