module main;
  int aa[int];
  int fails = 0;

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  initial begin
    aa[5] = 1;
    aa[2] = 1;
    aa[9] = 1;
    chk("$left", $left(aa), 0);
    chk("$right", $right(aa), 2147483647);
    chk("$low", $low(aa), 2);
    chk("$high", $high(aa), 9);
    chk("$increment", $increment(aa), -1);
    chk("$size", $size(aa), 3);
    aa.delete();
    if ($low(aa) !== 32'bx) begin
      fails++;
      $display("FAILED -- empty $low: got %b want x", $low(aa));
    end
    if ($high(aa) !== 32'bx) begin
      fails++;
      $display("FAILED -- empty $high: got %b want x", $high(aa));
    end
    chk("empty $size", $size(aa), 0);
    if (fails == 0) $display("PASS");
    $finish;
  end
endmodule
