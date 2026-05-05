// G44: unique case emits no spurious sorry message; G45: priority case works
module top;
  logic [1:0] sel;
  int res;
  initial begin
    // G44: unique case - no sorry message and correct result
    sel = 2'b01;
    unique case (sel)
      2'b00: res = 10;
      2'b01: res = 20;
      2'b10: res = 30;
      2'b11: res = 40;
    endcase
    if (res == 20)
      $display("G44_PASS: unique case fires correct branch");
    else
      $display("FAIL G44: res=%0d expected 20", res);

    // G45: priority case - first matching arm wins
    sel = 2'b11;
    priority case (1'b1)
      sel[1]: res = 100;
      sel[0]: res = 200;
      default: res = 999;
    endcase
    if (res == 100)
      $display("G45_PASS: priority case fires first match");
    else
      $display("FAIL G45: res=%0d expected 100", res);

    $finish;
  end
endmodule
