`timescale 1ns/1ps
module sv_sva_match_item_ranged_endpoint;
  logic clk = 0, start = 0, finish = 0;
  int endpoint_count = 0;
  always #5 clk = ~clk;

  task mark_endpoint();
    endpoint_count++;
    $display("endpoint-call");
  endtask

  sequence ranged;
    start ##[1:2] finish;
  endsequence

  sequence multi_endpoint;
    @(posedge clk) (ranged, mark_endpoint());
  endsequence

  c: cover property (multi_endpoint);

  initial begin
    @(negedge clk); start = 1; finish = 0;
    @(negedge clk); start = 0; finish = 1;
    @(negedge clk); finish = 1;
    @(negedge clk); finish = 0;
    repeat (2) @(negedge clk);
    if (endpoint_count != 2)
      $fatal(1, "endpoint calls=%0d expected=2", endpoint_count);
    $display("PASSED");
    $finish(0);
  end
endmodule
