module deferred_observed_fixed_array_action;
  int values[2] = '{7, 11};

  initial assert #0 (0) else $display("VALUES=%p", values);
endmodule
