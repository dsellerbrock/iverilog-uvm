module top;
  bit clk = 0;
  bit argument = 1;
  bit state = 0;

  function automatic bit writer(input bit value);
    state = value;
    writer = value;
  endfunction

  function automatic bit wrapper(input bit value);
    wrapper = writer(value);
  endfunction

  always #5 clk = ~clk;
  assert property (@(posedge clk) wrapper(argument));
endmodule
