module test_neg_option;
  bit a;
  covergroup cg;
    coverpoint a;
  endgroup
  cg c = new;
  initial begin
    c.option.nonexistent_member = 1;
  end
endmodule
