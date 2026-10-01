module top;
  covergroup cg with function sample(bit fg, logic flag);
    option.per_instance = 1;
    cp: coverpoint {fg, flag} {
      bins zero = {2'b00};
      bins one = {2'b11};
    }
  endgroup
  cg c;
  initial begin
    c = new;
    c.sample(0, 1'bx);
    $display("after X: %0f", c.cp.get_inst_coverage());
    c.sample(0, 1'bz);
    $display("after Z: %0f", c.cp.get_inst_coverage());
    if (c.cp.get_inst_coverage() != 0.0)
      $fatal(1, "X/Z sampled a known-value bin");
  end
endmodule
