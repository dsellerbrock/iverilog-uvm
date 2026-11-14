module main;
  bit clk = 0;
  bit a = 0;
  integer weak_fail = 0, indexed_fail = 0, strong_fail = 0, direct_fail = 0;
  always #5 clk = ~clk;

  property p; a; endproperty
  property alias_p; p; endproperty
  weak_check: assert property (@(posedge clk) nexttime p)
    else weak_fail = weak_fail + 1;
  indexed_check: assert property (@(posedge clk) nexttime[2] alias_p)
    else indexed_fail = indexed_fail + 1;
  strong_check: assert property (@(posedge clk) s_nexttime p)
    else strong_fail = strong_fail + 1;
  direct_check: assert property (@(posedge clk) nexttime a)
    else direct_fail = direct_fail + 1;

  initial begin
    #10;
    if (weak_fail || indexed_fail || strong_fail || direct_fail)
      $fatal(1, "failure on initial tick");
    a = 1;
    #10;
    if (weak_fail || indexed_fail || strong_fail || direct_fail)
      $fatal(1, "failure on true operand");
    a = 0;
    #10;
    if (weak_fail != 1 || indexed_fail != 1 || strong_fail != 1 || direct_fail != 1)
      $fatal(1, "wrong failure counts: %0d %0d %0d %0d", weak_fail, indexed_fail, strong_fail, direct_fail);
    a = 1;
    #10;
    if (weak_fail != 1 || indexed_fail != 1 || strong_fail != 1 || direct_fail != 1)
      $fatal(1, "unexpected later failure");
    $display("PASS");
    $finish(0);
  end
endmodule
