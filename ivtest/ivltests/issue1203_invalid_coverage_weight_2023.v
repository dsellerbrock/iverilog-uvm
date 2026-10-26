module issue1203_invalid_coverage_weight;
  bit a;

  covergroup negative_instance;
    option.weight = -1;
    cp: coverpoint a;
  endgroup

  covergroup fractional_instance;
    option.weight = 0.5;
    cp: coverpoint a;
  endgroup

  covergroup fractional_type;
    type_option.weight = 0.5;
    cp: coverpoint a;
  endgroup
endmodule
