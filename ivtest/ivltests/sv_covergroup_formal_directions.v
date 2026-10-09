module sv_covergroup_formal_directions;
  int observed;

  covergroup input_cg(input int value);
    cp: coverpoint value { bins captured = {0}; }
  endgroup

  covergroup ref_cg(ref int value);
    cp: coverpoint value { bins accepted = {0}; }
  endgroup

  input_cg input_instance;
  ref_cg ref_instance;

  initial begin
    observed = 0;
    input_instance = new(observed);
    ref_instance = new(observed);
    ref_instance.sample();
    observed = 1;
    input_instance.sample();
    if (input_instance.get_coverage() != 100.0)
      $fatal(1, "input covergroup formal did not keep its value copy");
    if (ref_instance.get_coverage() != 100.0)
      $fatal(1, "legal ref covergroup formal was rejected");
    $display("PASSED");
  end
endmodule
