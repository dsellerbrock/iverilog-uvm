module issue3792_bad_child #(parameter WORDS = 2)(inout wire p[WORDS]);
endmodule

module issue3792_bad_scalar(inout wire p);
endmodule

module issue3792_bad;
  logic variable_actual[2][2];
  issue3792_bad_child variable_split[0:1](variable_actual);

  logic coerced_actual[2];
  assign coerced_actual[0] = 1'b0;
  issue3792_bad_child coerced_single(coerced_actual);

  wire wrong_shape[3][2];
  issue3792_bad_child shape[0:1](wrong_shape);

  wire [1:0] wrong_type[2][2];
  issue3792_bad_child element_type[0:1](wrong_type);

  integer index = 0;
  wire dynamic_selection[2][2];
  issue3792_bad_child dynamic_row(dynamic_selection[index]);
  issue3792_bad_scalar variable_scalar[0:1](variable_actual[0]);

  wire single_is_not_arrayed[1][2];
  issue3792_bad_child extra_dimension(single_is_not_arrayed);

  wire varied[3][2];
  issue3792_bad_child uneven_formal[0:2](varied);
  defparam uneven_formal[1].WORDS = 3;
endmodule
