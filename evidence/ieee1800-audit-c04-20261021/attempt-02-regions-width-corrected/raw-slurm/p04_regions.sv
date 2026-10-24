module p04_regions;
  logic a = 0, b = 0, d = 0;
  logic [1:0] c = 0;
  always @(a) b <= 1;                                   // NBA region
  initial begin
    #1 a = 1; $display("R1 act b=%0d", b);              // Active: b=0
    #0 $display("R2 inact b=%0d", b);                   // Inactive, before NBA: b=0
  end
  initial begin #1 c <= 1; c <= 2; d <= c; end          // c ends 2; d samples old c (0)
  initial #1 $strobe("R5 post b=%0d c=%0d d=%0d", b, c, d);  // Postponed
endmodule
program p04_prog;
  initial #1 $display("R4 react b=%0d", p04_regions.b); // Reactive, after NBA
endprogram
