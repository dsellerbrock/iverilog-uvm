module top;
  bit clk = 0;
  bit argument = 1;

  function bit retained(input bit value);
    retained = retained ^ value;
  endfunction

  always #5 clk = ~clk;
  assert property (@(posedge clk) retained(argument));
endmodule
