module issue1203_fractional_instance_weight;
  bit a;
  covergroup cg;
    option.weight = 0.5;
    cp: coverpoint a;
  endgroup

  cg cov = new;

endmodule
