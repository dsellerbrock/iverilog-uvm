package p;
  class C;
    int calls;
    extern function lock_fuses();
    extern function bare;
    extern function unset();
    extern function void vf();
  endclass
  function C::lock_fuses();
    calls++;
    return 2'b10;
  endfunction
  function C::bare;
    return 1'b1;
  endfunction
  function C::unset();
  endfunction
  function void C::vf();
    calls += 10;
  endfunction
endpackage

module test;
  import p::*;
  C c;
  initial begin
    c = new();
    if (c.lock_fuses() !== 1'b0) begin $display("FAIL lock_fuses"); $finish(1); end
    if ({c.lock_fuses(), 2'b00} !== 3'b000) begin $display("FAIL width"); $finish(1); end
    if (c.bare() !== 1'b1) begin $display("FAIL bare"); $finish(1); end
    if (c.unset() !== 1'bx) begin $display("FAIL unset"); $finish(1); end
    c.vf();
    if (c.calls !== 12) begin $display("FAIL calls=%0d", c.calls); $finish(1); end
    $display("PASSED");
  end
endmodule
