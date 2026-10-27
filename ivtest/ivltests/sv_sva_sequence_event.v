module sv_sva_sequence_event;
  bit clk = 0;
  bit a = 0, b = 0, c = 0;
  integer first_wait = -1;
  integer paren_wait = -1;
  integer late_wait = -1;

  always #5 clk = ~clk;

  sequence abc;
    @(posedge clk) a ##1 b ##1 c;
  endsequence

  initial begin
    fork
      begin
        @abc;
        first_wait = $time;
      end
      begin
        @(abc);
        paren_wait = $time;
      end
      begin
        #20;
        @abc;
        late_wait = $time;
      end
      begin
        #10 a = 1;
        #10 b = 1;
        #10 c = 1;
      end
    join

    if (first_wait != 35 || paren_wait != 35 || late_wait != 45)
      $fatal(1, "sequence event times: %0d %0d %0d", first_wait,
             paren_wait, late_wait);

    $display("PASS: sequence events at %0d %0d %0d", first_wait,
             paren_wait, late_wait);
    $finish;
  end
endmodule
