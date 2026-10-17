module top;
  class CA; rand bit [7:0] x; endclass
  class C2;
    bit [7:0] y = 5;
    function int lthis(CA f);
      return f.randomize() with { x == local::this.y; };
    endfunction
  endclass
  CA a; C2 c;
  initial begin
    a = new; c = new;
    if (!c.lthis(a) || a.x != 5) $fatal(1, "local::this did not bind to caller object");
    $display("DONE local::this");
  end
endmodule
