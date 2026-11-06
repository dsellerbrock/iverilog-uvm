module tb;
  bit a = 0, b = 0;

  covergroup cg;
    option.per_instance = 1;
    option.cross_num_print_missing = 0;
    cp_a: coverpoint a { bins a0 = {0}; bins a1 = {1}; }
    cp_b: coverpoint b { bins b0 = {0}; bins b1 = {1}; }
    x_default: cross cp_a, cp_b;
    x_override: cross cp_a, cp_b {
      option.cross_num_print_missing = 1;
    }
  endgroup

  cg c = new;

  initial begin
    c.sample();
    $display("PASSED");
    $finish;
  end
endmodule
