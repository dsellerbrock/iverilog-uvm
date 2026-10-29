module issue1465_cross_num_print_missing;
  bit a, b;

  covergroup no_missing;
    cp_a: coverpoint a { bins vals[] = {0, 1}; }
    cp_b: coverpoint b { bins vals[] = {0, 1}; }
    x: cross cp_a, cp_b { option.cross_num_print_missing = 0; }
  endgroup

  covergroup one_missing;
    cp_a: coverpoint a { bins vals[] = {0, 1}; }
    cp_b: coverpoint b { bins vals[] = {0, 1}; }
    x: cross cp_a, cp_b { option.cross_num_print_missing = 1; }
  endgroup

  no_missing cg0;
  one_missing cg1;
  initial begin
    cg0 = new;
    cg1 = new;
    cg0.sample();
    cg1.sample();
    $display("issue1465_cross_num_print_missing PASS");
  end
endmodule
