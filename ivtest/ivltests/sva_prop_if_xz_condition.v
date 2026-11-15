// IEEE 1800-2023 16.6: an assertion Boolean expression that is x or z is
// false, so a property if (16.12.6) with an x or z condition selects its
// else branch, or succeeds vacuously when there is none.
module sva_prop_if_xz_condition;
  bit clk = 0;
  logic sel;
  int p1, f1, p2, f2, p3, f3;
  always #5 clk = ~clk;
  // sel is x at the 5 edge, z at 15, 0 at 25, 1 at 35.
  initial begin sel = 1'bx; #10 sel = 1'bz; #10 sel = 0; #10 sel = 1; end
  a1: assert property (@(posedge clk) if (sel) 1'b0 else 1'b1) p1++; else f1++;
  a2: assert property (@(posedge clk) if (sel) 1'b0) p2++; else f2++;
  a3: assert property (@(posedge clk) if (sel) 1'b1 else 1'b0) p3++; else f3++;
  initial #40 begin
    $display("if-else   pass=%0d fail=%0d", p1, f1);
    $display("if        pass=%0d fail=%0d", p2, f2);
    $display("inverted  pass=%0d fail=%0d", p3, f3);
    $finish;
  end
endmodule
