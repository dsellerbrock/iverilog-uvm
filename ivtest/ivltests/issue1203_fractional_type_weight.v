module issue1203_fractional_type_weight;
  bit a;
  covergroup cg;
    type_option.weight = 0.5;
    cp: coverpoint a;
  endgroup

  cg cov = new;

endmodule
