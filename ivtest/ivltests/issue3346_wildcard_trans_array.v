module issue3346_wildcard_trans_array;
  covergroup cg with function sample(input logic [1:0] value);
    cp: coverpoint value {
      wildcard bins paths[] = (2'b0x => 2'b1x);
    }
  endgroup
  covergroup repeats with function sample(input logic [1:0] value);
    cp: coverpoint value {
      wildcard bins paths[] = (2'b0x, 2'b00 [*2] => 2'b1x);
    }
  endgroup
  cg c = new;
  cg interrupted = new;
  repeats r = new;

  initial begin
    if (c.get_inst_coverage() != 0.0) $fatal(1, "initial coverage");
    c.sample(2'b00); c.sample(2'b10);
    if (c.get_inst_coverage() != 25.0) $fatal(1, "first transition");
    c.sample(2'b00); c.sample(2'b11);
    if (c.get_inst_coverage() != 50.0) $fatal(1, "second transition");
    c.sample(2'b01); c.sample(2'b10);
    if (c.get_inst_coverage() != 75.0) $fatal(1, "third transition");
    c.sample(2'b01); c.sample(2'b11);
    if (c.get_inst_coverage() != 100.0) $fatal(1, "fourth transition");
    interrupted.sample(2'b00); interrupted.sample(2'bxx);
    interrupted.sample(2'b10);
    if (interrupted.get_inst_coverage() != 0.0) $fatal(1, "X interrupted transition");
    interrupted.sample(2'b01); interrupted.sample(2'b1z);
    if (interrupted.get_inst_coverage() != 0.0) $fatal(1, "Z endpoint");
    interrupted.sample(2'b01); interrupted.sample(2'b11);
    if (interrupted.get_inst_coverage() != 25.0) $fatal(1, "recovery");
    r.sample(2'b00); r.sample(2'b01); r.sample(2'b10);
    if (r.get_inst_coverage() != 12.5) $fatal(1, "repeated alternatives");
    r.sample(2'b00); r.sample(2'b01); r.sample(2'b11);
    if (r.get_inst_coverage() != 25.0) $fatal(1, "repeated alternatives second hit");
    $display("PASSED");
  end
endmodule
