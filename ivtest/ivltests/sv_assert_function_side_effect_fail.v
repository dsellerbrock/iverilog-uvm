module top;
  bit clk = 0;
  int calls;
  function automatic bit stateful();
    calls++;
    return calls < 3;
  endfunction
  always #5 clk = ~clk;
  assert property (@(posedge clk) stateful());
endmodule
