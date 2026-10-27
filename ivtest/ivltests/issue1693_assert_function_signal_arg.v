module top;
  bit clk = 0;
  logic operand = 1'b1;
  int pass_count, fail_count;

  always #5 clk = ~clk;

  function automatic logic identity(input logic value);
    identity = value;
  endfunction

  assert property (@(posedge clk) identity(operand)) pass_count++;
  else fail_count++;

  initial begin
    #12;
    if (pass_count != 1 || fail_count != 0)
      $fatal(1, "pass=%0d fail=%0d", pass_count, fail_count);
    $display("PASSED");
    $finish(0);
  end
endmodule
