checker c(logic clk);
  bit q;
  bit r;
  always_ff @(posedge clk) q <= 1'b1;
  always_comb r = q;
endchecker
module sv_checker_always_ff_assignments;
  logic clk = 0;
  c i(clk);
  initial begin
    #1 clk = 1;
    #1 $display("ISSUE946_ALLOWED_ASSIGNMENTS_OK");
  end
endmodule
