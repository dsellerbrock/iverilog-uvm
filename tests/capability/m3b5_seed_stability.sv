module top;
  class C; rand bit [7:0] v; endclass
  initial begin automatic C a=new, b=new; int s1,s2; bit ok=1;
    a.srandom(42); b.srandom(42);
    void'(a.randomize()); void'(b.randomize());
    if (a.v !== b.v) begin $display("FAIL same-seed differs %0d vs %0d",a.v,b.v); ok=0; end
    if (ok) $display("PASS"); $finish(0); end
endmodule
