module issue3003_property_x;
  bit clk = 0;
  logic [1:0] a, b;
  logic [1:0] values [0:5];
  integer op = 0, ofail = 0, ap = 0, afail = 0;
  integer eop = 0, eofail = 0, eap = 0, eafail = 0;
  always #5 clk = ~clk;
  assert property (@(posedge clk) (a) or (b)) op++; else ofail++;
  assert property (@(posedge clk) (a) and (b)) ap++; else afail++;
  initial begin
    values[0] = 0; values[1] = 1; values[2] = 'x;
    values[3] = 'z; values[4] = 2'b1x; values[5] = 2'b0x;
    for (integer i = 0; i < 6; i++) begin
      for (integer j = 0; j < 6; j++) begin
        a = values[i]; b = values[j];
        if (a || b) eop++; else eofail++;
        if (a) begin
          if (b) eap++; else eafail++;
        end else eafail++;
        @(posedge clk); #1;
        if (op != eop || ofail != eofail || ap != eap || afail != eafail)
          $fatal(1, "a=%b b=%b or=%0d/%0d expected=%0d/%0d and=%0d/%0d expected=%0d/%0d",
                 a, b, op, ofail, eop, eofail, ap, afail, eap, eafail);
        @(negedge clk);
      end
    end
    $display("PASS");
    $finish(0);
  end
endmodule
