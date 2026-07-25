// Control: no edge descriptor -> BOTH transitions arm the check, so two
// violations. If edge01.sv also reports two, the descriptor is ignored.
module dff(input clk, d); specify $setup(d, posedge clk, 10); endspecify endmodule
module tb; reg c=0, d=0; dff u(c,d);
  initial begin
    #10 d=1; #1 c=1;
    #10 c=0;
    #10 d=0; #1 c=1;
    #10 $display("DONE (expect TWO violations)");
    $finish(0);
  end
endmodule
