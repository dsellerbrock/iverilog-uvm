// Issue #2857: whole-array continuous assignments are VPI objects.
module top;
  logic [3:0] sarr [2];
  wire [3:0] arr [2];
  assign arr = sarr;
  initial begin
    sarr[0] = 4'd3;
    sarr[1] = 4'd5;
    #1 $probe;
    $display("DONE");
    $display("PASSED");
  end
endmodule
