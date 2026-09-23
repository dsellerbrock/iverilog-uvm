module top;
  class packet;
    rand int n = 99;
    int state_value;
    function int value(); return state_value; endfunction
`ifdef CLASS_CONTROL
    constraint c { n == value(); }
`endif
    function void pre_randomize(); top.current = top.other; endfunction
  endclass
  packet current, other, original;
  initial begin
    original = new; other = new; current = original;
    original.state_value = 3; other.state_value = 9;
`ifdef CLASS_CONTROL
    if (!current.randomize()) $fatal(1, "solve failed");
`else
    if (!current.randomize() with { n == value(); }) $fatal(1, "solve failed");
`endif
    if (current != other || original.n != 3 || other.n != 99)
      $fatal(1, "wrong retained receiver original=%0d other=%0d",original.n,other.n);
    $display("PASS retained target after pre rebind");
  end
endmodule
