module test;
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
  covergroup unknown_type_weight;
    type_option.weight = 'x;
    cp: coverpoint a;
  endgroup
  covergroup fractional_item_weights;
    x_cp: coverpoint a { option.weight = 0.5; type_option.weight = 0.5; }
    y_cp: coverpoint a;
    xy: cross x_cp, y_cp { option.weight = 0.5; type_option.weight = 0.5; }
  endgroup
  negative_instance_weight negative;
  fractional_instance_weight fractional;
  fractional_type_weight typed;
  unknown_type_weight unknown;
  fractional_item_weights items;
  initial begin
    negative = new;
    fractional = new;
    typed = new;
    unknown = new;
    items = new;
  end
endmodule
