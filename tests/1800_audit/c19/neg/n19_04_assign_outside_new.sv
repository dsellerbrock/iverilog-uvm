module top;
  class K;
    bit v;
    covergroup cv; coverpoint v; endgroup
    function new(); cv = new; endfunction
    function void f(); cv = new; endfunction
  endclass
endmodule
