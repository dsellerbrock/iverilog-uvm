module issue3136_clocking_select;
  logic clk = 0;
  logic [3:0] d = 4'b1001;
  logic [7:4] shifted = 4'b1010;
  integer idx = 0;
  integer failures = 0, checks = 0;
  always #5 clk = !clk;
  clocking cb @(posedge clk);
    input m = d;
    input n = shifted;
    input expr = d ^ 4'b0011;
    input slice = d[3:1];
    input d;
  endclocking
  assert property (@(posedge clk) cb.m[0] == d[0]) checks++; else failures++;
  assert property (@(posedge clk) cb.m[3:2] == d[3:2]) checks++; else failures++;
  assert property (@(posedge clk) cb.m[idx] == d[idx]) checks++; else failures++;
  assert property (@(posedge clk) cb.n[7] == shifted[7]) checks++; else failures++;
  assert property (@(posedge clk) cb.n[5:4] == shifted[5:4]) checks++; else failures++;
  assert property (@(posedge clk) cb.slice[0] == d[1]) checks++; else failures++;
  assert property (@(posedge clk) cb.expr[0] == (d[0] ^ 1'b1)) checks++; else failures++;
  assert property (@(posedge clk) cb.d[0] == d[0]) checks++; else failures++;
  assert property (@(posedge clk) cb.m[0] |-> cb.m != 4'b0010) checks++; else failures++;
  initial begin
    #17 d = 4'b0010; shifted = 4'b0101; idx = 1;
    #8 idx = 0;
    #12;
    if (failures || checks != 36) $display("FAIL checks=%0d failures=%0d", checks, failures);
    else $display("PASS clocking select");
    $finish(0);
  end
endmodule
