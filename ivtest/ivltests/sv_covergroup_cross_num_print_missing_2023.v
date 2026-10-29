module tb;
  bit a, b;
  covergroup cg;
    cp_a: coverpoint a { bins values[] = {0, 1}; }
    cp_b: coverpoint b { bins values[] = {0, 1}; }
    cr: cross cp_a, cp_b {
      option.cross_num_print_missing = 1;
    }
    cr_zero: cross cp_a, cp_b {
      option.cross_num_print_missing = 0;
    }
  endgroup
  cg c = new;
  initial begin
    c.sample();
    $display("PASSED");
  end
endmodule
