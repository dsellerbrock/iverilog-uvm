module top;
  int count;
  initial begin
    count = 0;
    repeat (2) count++;
    while (count < 3) count++;
    if (count != 3) $fatal(1, "loop statement regression");
    $display("PASSED");
    $finish;
  end
endmodule
