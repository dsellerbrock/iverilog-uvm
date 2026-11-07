module issue2695_sequence_triggered_empty;
  bit clk, a;
  int checks, errors;

  always #5 clk = ~clk;

  sequence empty;
    a[*0];
  endsequence

  assert property (@(posedge clk) !empty.triggered) checks++;
  else errors++;

  initial begin
    repeat (2) @(negedge clk);
    if (checks != 2 || errors)
      $fatal(1, "empty triggered=%0d/%0d", checks, errors);
    $display("PASS fixed empty sequence does not trigger");
    $finish(0);
  end
endmodule
