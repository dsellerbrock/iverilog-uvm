module sv_covergroup_writable_increment;
  logic actual;

  covergroup writable_cg;
    cp: coverpoint actual++;
  endgroup

  writable_cg control;
  initial begin
    actual = 0;
    control = new;
    control.sample();
    if (actual !== 1'b1)
      $fatal(1, "writable coverpoint increment was not evaluated");
    $display("PASSED");
  end
endmodule
