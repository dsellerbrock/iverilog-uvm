module issue1203_coverage_weight_invalid;
  bit a, b;

  covergroup negative_instance_weight;
    option.weight = -1;
    cp: coverpoint a;
  endgroup

  covergroup fractional_instance_weight;
    cp: coverpoint a { option.weight = 0.5; }
    cp_b: coverpoint b;
    cx: cross cp, cp_b { option.weight = 0.5; }
  endgroup

  covergroup fractional_type_group_weight;
    type_option.weight = 0.5;
    cp: coverpoint a;
  endgroup

  covergroup fractional_type_item_weight;
    cp: coverpoint a { type_option.weight = 0.5; }
    cp_b: coverpoint b;
    cx: cross cp, cp_b { type_option.weight = 0.5; }
  endgroup

  negative_instance_weight negative_cov;
  fractional_instance_weight fractional_cov;
  fractional_type_group_weight fractional_type_cov;
  fractional_type_item_weight fractional_type_item_cov;

  initial begin
    negative_cov = new;
    fractional_cov = new;
    fractional_type_cov = new;
    fractional_type_item_cov = new;
  end
endmodule
