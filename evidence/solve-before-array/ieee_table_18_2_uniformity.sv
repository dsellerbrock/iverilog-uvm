class B;  rand bit s; rand bit [31:0] d; constraint c { s -> d == 0; } endclass
class BO; rand bit s; rand bit [31:0] d; constraint c { s -> d == 0; } constraint order { solve s before d; } endclass
module top; B b; BO bo; int s1, d0, os1, od0; initial begin b = new; bo = new;
  repeat (1000) begin void'(b.randomize()); s1 += b.s; d0 += (b.d == 0); void'(bo.randomize()); os1 += bo.s; od0 += (bo.d == 0); end
  $display("unordered: s=1 %0d/1000 d==0 %0d/1000 (IEEE ~0)", s1, d0);
  $display("ordered:   s=1 %0d/1000 d==0 %0d/1000 (IEEE ~500)", os1, od0); end endmodule
