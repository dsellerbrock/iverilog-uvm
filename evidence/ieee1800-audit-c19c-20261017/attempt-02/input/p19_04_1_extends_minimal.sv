module top;
  class base;
    bit v;
    covergroup g1; coverpoint v; endgroup
    function new(); g1 = new; endfunction
  endclass
  class derived extends base;
    covergroup extends g1; endgroup : g1
    function new(); super.new(); endfunction
  endclass
  derived d;
  initial begin d = new; d.v = 1; d.g1.sample();
    $display("INFO minimal_derived_coverage=%f", d.g1.get_inst_coverage()); end
endmodule
