module issue1203_negative_weight;
  bit a;
  covergroup cg;
    option.weight = -1;
    cp: coverpoint a;
  endgroup

  cg cov = new;

endmodule
