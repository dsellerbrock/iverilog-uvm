module issue1708_concat_bit_2state;
  bit [1:0] b;
  logic [2:0] g;
  logic [4:0] l;

  initial begin
    {b, g} = 5'bxxxxx;
    if (b !== 2'b00 || g !== 3'bxxx)
      $fatal(1, "concatenation assignment: b=%b g=%b", b, g);

    l = 5'bxxxxx;
    b = l[4:3];
    if (b !== 2'b00)
      $fatal(1, "part-select assignment: b=%b", b);

    {b, g} = 5'b00000;
    {b, g} += 5'bxxxxx;
    if (b !== 2'b00 || g !== 3'bxxx)
      $fatal(1, "compound concatenation assignment: b=%b g=%b", b, g);

    $display("ISSUE1708_CONCAT_BIT_2STATE_PASSED");
    $display("PASSED");
  end
endmodule
