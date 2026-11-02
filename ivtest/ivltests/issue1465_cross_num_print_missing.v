module tb;
  bit a, b;

  covergroup cg(int default_missing, int cross_missing);
    option.per_instance = 1;
    option.cross_num_print_missing = default_missing;

    cp_a: coverpoint a;
    cp_b: coverpoint b;
    default_cross: cross cp_a, cp_b;
    override_cross: cross cp_a, cp_b {
      option.cross_num_print_missing = cross_missing;
    }
  endgroup

  cg c0, c1, c2;

  initial begin
    c0 = new(2, 0);
    c1 = new(2, 1);
    c2 = new(2, 2);
    c0.sample();
    c1.sample();
    c2.sample();
    $display("PASSED");
    $finish;
  end
endmodule
