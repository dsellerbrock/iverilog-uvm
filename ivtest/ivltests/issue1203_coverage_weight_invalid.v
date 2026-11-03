module issue1203_coverage_weight_invalid;
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

  covergroup fractional_item_type_weight;
    cp: coverpoint a {
      type_option.weight = 0.5;
    }
  endgroup

  negative_instance_weight negative = new;
  fractional_instance_weight fractional_instance = new;
  fractional_type_weight fractional_type = new;
  fractional_item_type_weight fractional_item_type = new;
endmodule
