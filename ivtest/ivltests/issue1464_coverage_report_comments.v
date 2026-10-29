module tb;
  bit a = 0, b = 0;

  covergroup cg;
    option.per_instance = 1;
    option.comment = "INSTANCE_COMMENT";
    type_option.comment = "TYPE_COMMENT";
    cp_a: coverpoint a {
      option.comment = "COVERPOINT_COMMENT";
      type_option.comment = "TYPE_COVERPOINT_COMMENT";
    }
    cp_b: coverpoint b;
    cr: cross cp_a, cp_b {
      option.comment = "CROSS_COMMENT";
      type_option.comment = "TYPE_CROSS_COMMENT";
    }
  endgroup

  cg c = new;

  initial begin
    c.sample();
    $display("PASSED");
    $finish;
  end
endmodule
