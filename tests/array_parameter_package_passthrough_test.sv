package array_parameter_package_passthrough_pkg;
  typedef struct packed {
    logic       enable;
    logic [6:0] address;
  } entry_t;

  localparam entry_t ResetEntries[2] = '{
    '{enable: 1'b0, address: 7'h12},
    '{enable: 1'b1, address: 7'h65}
  };
endpackage

module array_parameter_package_passthrough_leaf #(
  parameter array_parameter_package_passthrough_pkg::entry_t Entries[2] =
      array_parameter_package_passthrough_pkg::ResetEntries
);
  initial begin
    if (Entries[0] !== 8'h12 || Entries[1] !== 8'he5)
      $fatal(1, "array parameter pass-through failed: %h %h", Entries[0], Entries[1]);
  end
endmodule

module array_parameter_package_passthrough_mid #(
  parameter array_parameter_package_passthrough_pkg::entry_t MidEntries[2] =
      array_parameter_package_passthrough_pkg::ResetEntries
);
  array_parameter_package_passthrough_leaf #(.Entries(MidEntries)) leaf();
endmodule

module array_parameter_package_passthrough_test;
  array_parameter_package_passthrough_mid mid();
  initial begin
    #1;
    $display("PASS: package-qualified array parameter pass-through");
  end
endmodule
