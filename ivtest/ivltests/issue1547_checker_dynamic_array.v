logic clk = 0;
int values[] = '{1};
checker c;
  a: assert property (@(posedge clk) values[0] == 1);
endchecker
module issue1547_checker_dynamic_array;
  c ci();
  initial begin forever #5 $unit::clk = ~$unit::clk; end
  initial #12 $finish;
endmodule
