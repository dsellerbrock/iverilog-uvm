// IEEE1800-2017/2023 9.2 and10.4: absent clocked assignments retain state.
module reset_only_dut #(parameter [7:0] RESET=0)(
 input clk, rst_n, output reg [7:0] q);
 always @(posedge clk or negedge rst_n) if (!rst_n) q <= RESET;
endmodule
module test;
 reg clk=0, rst_n=1;
 wire [7:0] clear_q, set_q, mixed_q;
 reset_only_dut #(8'h00) clear_dut(clk,rst_n,clear_q);
 reset_only_dut #(8'hff) set_dut(clk,rst_n,set_q);
 reset_only_dut #(8'ha5) mixed_dut(clk,rst_n,mixed_q);
 always #5 clk=~clk;
 task check_reset;
  if (clear_q!==8'h00 || set_q!==8'hff || mixed_q!==8'ha5)
   $fatal(1,"reset-only outputs did not reset/hold");
 endtask
 initial begin
  #2;
  if (clear_q!==8'hxx || set_q!==8'hxx || mixed_q!==8'hxx)
   $fatal(1,"four-state initial value lost");
  rst_n=0; #1; check_reset();
  #1 rst_n=1;
  repeat(3) begin @(posedge clk); #1; check_reset(); end
  #1 rst_n=0; #1; check_reset();
  #1 rst_n=1; #1; check_reset();
  $display("PASSED"); $finish(0);
 end
endmodule
