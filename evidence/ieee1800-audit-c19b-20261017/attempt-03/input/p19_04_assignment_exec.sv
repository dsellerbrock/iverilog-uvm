module top;
  class K;
    bit v;
    covergroup cv; coverpoint v; endgroup
    function new(); cv = new; endfunction
    function void f(); cv = new; endfunction
  endclass
  K k = new;
  initial begin
    k.v = 1; k.cv.sample();
    $display("INFO before=%f", k.cv.get_inst_coverage());
    k.f();
    $display("INFO after_reassignment=%f", k.cv.get_inst_coverage());
  end
endmodule
