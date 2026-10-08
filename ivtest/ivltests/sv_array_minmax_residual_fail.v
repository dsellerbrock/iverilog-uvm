// min/max on arrays of non-integral elements remains unsupported.
module real_dynamic_receiver;
  real values[];
  real result[$];

  initial result = values.min;
endmodule

module string_dynamic_receiver;
  string values[];
  string result[$];

  initial result = values.max;
endmodule
