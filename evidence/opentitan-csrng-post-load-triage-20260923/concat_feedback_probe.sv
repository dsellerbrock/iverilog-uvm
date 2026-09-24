module concat_feedback_probe;
  wire [7:0] words [0:0];
  assign words[0] = {words[0][3:0], words[0][7:4]};
  initial begin
    #1;
    $display("PASS feedback settled: %h", words[0]);
    $finish(0);
  end
endmodule
