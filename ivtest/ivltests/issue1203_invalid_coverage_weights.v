module issue1203_invalid_coverage_weights;
  bit a;
  covergroup negative_instance_weight;
    option.weight = -1;
    cp: coverpoint a;
  endgroup
  covergroup fractional_instance_weight;
    option.weight = 0.5;
    cp: coverpoint a;
  endgroup
  covergroup fractional_type_weight;
    type_option.weight = 0.5;
    cp: coverpoint a;
  endgroup
  negative_instance_weight n = new;
  fractional_instance_weight i = new;
  fractional_type_weight t = new;
endmodule
