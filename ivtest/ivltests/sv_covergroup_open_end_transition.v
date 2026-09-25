module test;
  covergroup transition_cg with function sample(bit [7:0] value);
    option.per_instance = 1;
    cp: coverpoint value { bins end_at_zero = ([1:$] => 0); }
  endgroup
  covergroup lower_transition_cg with function sample(bit [7:0] value);
    option.per_instance = 1;
    cp: coverpoint value { bins end_at_four = ([$:3] => 4); }
  endgroup
  transition_cg tc = new;
  lower_transition_cg lc = new;
  initial begin
    tc.sample(0);
    if (tc.get_inst_coverage() != 0.0)
      $fatal(1, "transition matched without a start");
    tc.sample(255);
    tc.sample(0);
    if (tc.get_inst_coverage() != 100.0)
      $fatal(1, "open transition start was dropped");
    lc.sample(0);
    lc.sample(4);
    if (lc.get_inst_coverage() != 100.0)
      $fatal(1, "lower-open transition start was dropped");
    $display("PASSED");
  end
endmodule
