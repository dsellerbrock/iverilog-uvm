module sv_repeat_event_unknown_count;
  logic clk = 1'b0;
  logic [3:0] count;
  integer signed_count;
  integer value;

  always #5 clk = ~clk;

  initial begin
    count = 4'bxxxx;
    value = 0;
    value = repeat (count) @(posedge clk) 11;
    if (value != 11 || $time != 0)
      $fatal(1, "X repeat count: value=%0d time=%0t", value, $time);

    count = 4'bzzzz;
    value = 0;
    value = repeat (count) @(posedge clk) 22;
    if (value != 22 || $time != 0)
      $fatal(1, "Z repeat count: value=%0d time=%0t", value, $time);

    count = 0;
    value = repeat (count) @(posedge clk) 33;
    if (value != 33 || $time != 0)
      $fatal(1, "zero repeat count: value=%0d time=%0t", value, $time);

    signed_count = -1;
    value = repeat (signed_count) @(posedge clk) 44;
    if (value != 44 || $time != 0)
      $fatal(1, "negative repeat count: value=%0d time=%0t", value, $time);

    count = 2;
    value = repeat (count) @(posedge clk) 55;
    if (value != 55 || $time != 15)
      $fatal(1, "positive repeat count: value=%0d time=%0t", value, $time);

    $display("PASSED");
    $finish;
  end

  initial begin
    #100;
    $fatal(1, "repeat event control did not complete");
  end
endmodule
