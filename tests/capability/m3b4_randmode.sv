module top;
  class C; rand int x; rand int y; constraint cy { y == 5; }
    function new; x=0; y=0; endfunction endclass
  initial begin automatic C c = new; int ok=1;
    c.x.rand_mode(0); c.x = 77;
    if (!c.randomize()) ok=0;
    if (c.x != 77) begin $display("FAIL rand_mode(0) did not freeze x=%0d",c.x); ok=0; end
    c.cy.constraint_mode(0); c.y = 99;
    if (!c.randomize()) ok=0;
    if (ok) $display("PASS"); $finish(0); end
endmodule
