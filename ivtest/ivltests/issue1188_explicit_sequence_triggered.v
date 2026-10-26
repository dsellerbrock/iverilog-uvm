module issue1188_explicit_sequence_triggered;
  logic clk = 0, a = 1, b = 1, reset = 1, branch = 1;
  always #5 clk = ~clk;

  sequence source_seq;
    @(posedge clk) a ##1 b;
  endsequence

  sequence destination_seq;
    @(posedge clk) reset ##1 source_seq.triggered ##1 branch;
  endsequence

  assert property (destination_seq);

  initial begin
    #36 $display("PASS explicit sequence .triggered");
    $finish;
  end
endmodule
