module top;
  bit a, b;

  covergroup cg;
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    cp_a: coverpoint a { bins zero = {0}; bins one = {1}; }
    cp_b: coverpoint b { bins zero = {0}; bins one = {1}; }
  endgroup

  cg first = new;
  cg second = new;

  initial begin
    a = 0;
    b = 0;
    first.sample();
    a = 1;
    second.sample();

    if (cg::get_coverage() != 75.0)
      $fatal(1, "covergroup type coverage mismatch: %0.2f",
             cg::get_coverage());
    if (cg::cp_a::get_coverage() != 100.0)
      $fatal(1, "coverpoint A type coverage mismatch: %0.2f",
             cg::cp_a::get_coverage());
    if (cg::cp_b::get_coverage() != 50.0)
      $fatal(1, "coverpoint B type coverage mismatch: %0.2f",
             cg::cp_b::get_coverage());
    if (first.get_inst_coverage() != 50.0
        || second.get_inst_coverage() != 50.0)
      $fatal(1, "covergroup instance coverage changed");

    $display("type cg=%0.2f cp_a=%0.2f cp_b=%0.2f",
             cg::get_coverage(), cg::cp_a::get_coverage(),
             cg::cp_b::get_coverage());
    $display("PASSED");
  end
endmodule
