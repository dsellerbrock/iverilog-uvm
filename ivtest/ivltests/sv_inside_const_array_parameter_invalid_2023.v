module sv_inside_const_array_parameter_invalid_2023;
  parameter int values [0:1] = '{1, 2};
  int lhs [0:1];
  initial if (lhs inside {values}) $display("invalid");
endmodule
