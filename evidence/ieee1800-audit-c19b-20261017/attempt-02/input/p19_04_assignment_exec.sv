module top;
  class K;
    bit v;
    covergroup cv; coverpoint v; endgroup
    function new(); cv = new; endfunction
    function void f(); cv = new; endfunction
  endclass
  K k = new;
  initial begin k.f(); k.cv.sample(); $display("RAN 19.4.assignment_outside_new cov=%f", k.cv.get_inst_coverage()); end
endmodule
