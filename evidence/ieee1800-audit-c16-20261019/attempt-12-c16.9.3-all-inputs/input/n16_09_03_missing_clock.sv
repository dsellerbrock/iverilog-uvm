module test;
  logic sampled = 1'b1;
  initial begin
    $display("NO_CLOCK_PAST=%b", $past(sampled));
    $finish;
  end
endmodule
