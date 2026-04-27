// Test SV ternary with string operands.
module top;
   bit b;
   string s;
   string ral = "uart_reg_block";
   initial begin
      b = 1;
      s = b ? "clk_rst_vif" : {"clk_rst_vif_", ral};
      $display("b=1: s='%0s'", s);
      if (s != "clk_rst_vif") begin
         $display("FAIL: ternary b=1 with concat-else returned '%0s'", s); $finish;
      end
      b = 0;
      s = b ? "clk_rst_vif" : {"clk_rst_vif_", ral};
      $display("b=0: s='%0s'", s);
      if (s != "clk_rst_vif_uart_reg_block") begin
         $display("FAIL: ternary b=0 with concat-else returned '%0s'", s); $finish;
      end
      $display("STRING TERNARY+CONCAT: PASS");
      $finish;
   end
endmodule
