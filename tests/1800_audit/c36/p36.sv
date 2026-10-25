module p36;
  integer r = 5;
  wire w1, w2;
  assign w1 = 1'b1;
  assign w2 = w1;
  initial begin
    $probe36;
    #1 r = 1;
    #1 r = 2;
    #1 r = 3;
    #1 $report36;
  end
endmodule
