// M13 negative: trireg (charge-storage) nets model switch-level charge
// decay, which is outside the verification mission. They must be a loud
// sorry, never silently miscompiled into an ordinary net.
module top;
  trireg (large) #(0, 0, 50) cap;
  reg d = 1, en = 1;
  bufif1 b(cap, d, en);
  initial begin
    #10 $display("cap=%b", cap);
    $finish(0);
  end
endmodule
