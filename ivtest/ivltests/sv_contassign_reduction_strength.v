module sv_contassign_reduction_strength;
  reg en, data;
  wire pin, weak_pin, default_pin;

  assign pin = en ? data : 1'bz;
  assign (highz0, pull1) pin = !en;

  assign (weak0, weak1) weak_pin = !en;
  assign weak_pin = en ? 1'b0 : 1'bz;
  assign default_pin = !en;

  initial begin
    en = 0; data = 0;
    #1;
    if (pin !== 1'b1 || weak_pin !== 1'b1 || default_pin !== 1'b1)
      $fatal(1, "idle pin=%b weak=%b default=%b", pin, weak_pin, default_pin);
    en = 1; data = 0;
    #1;
    if (pin !== 1'b0 || weak_pin !== 1'b0 || default_pin !== 1'b0)
      $fatal(1, "strong0 pin=%b weak=%b default=%b", pin, weak_pin, default_pin);
    data = 1;
    #1;
    if (pin !== 1'b1 || weak_pin !== 1'b0 || default_pin !== 1'b0)
      $fatal(1, "strong1 pin=%b weak=%b default=%b", pin, weak_pin, default_pin);
    data = 1'bx;
    #1;
    if (pin !== 1'bx || weak_pin !== 1'b0 || default_pin !== 1'b0)
      $fatal(1, "x pin=%b weak=%b default=%b", pin, weak_pin, default_pin);
    en = 1'bx;
    #1;
    if (pin !== 1'bx || default_pin !== 1'bx)
      $fatal(1, "unknown enable pin=%b default=%b", pin, default_pin);
    $display("PASSED");
    $finish(0);
  end
endmodule
