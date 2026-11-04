module issue1465_cross_num_print_missing;
  covergroup cg with function sample(bit a, bit b);
    option.cross_num_print_missing = 2;
    cp_a: coverpoint a { bins values[] = {0, 1}; }
    cp_b: coverpoint b { bins values[] = {0, 1}; }
    default_cross: cross cp_a, cp_b;
    one_missing_cross: cross cp_a, cp_b {
      option.cross_num_print_missing = 1;
    }
    no_missing_cross: cross cp_a, cp_b {
      option.cross_num_print_missing = 0;
    }
  endgroup

  cg coverage = new;

  initial begin
    coverage.sample(0, 0);
    $display("PASSED");
    $finish;
  end
endmodule
