// $setup(edge[01] d, posedge clk, 10): only a 0->1 transition of d arms
// the check. A 1->0 transition close to the clock must NOT violate.
module dff(input clk, d); specify $setup(edge[01] d, posedge clk, 10); endspecify endmodule
module tb; reg c=0, d=0; dff u(c,d);
  initial begin
    // Case A: d rises at 10, clock at 11 -> setup 1 < 10, and the edge
    // IS 0->1, so this MUST report a violation.
    #10 d=1; #1 c=1;
    #10 c=0;
    // Case B: d FALLS at 21, clock at 22 -> setup 1 < 10, but the edge
    // is 1->0, which edge[01] excludes, so this must NOT report.
    #10 d=0; #1 c=1;
    #10 $display("DONE (expect exactly ONE violation, at time 11)");
    $finish(0);
  end
endmodule
