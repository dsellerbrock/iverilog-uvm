package imported_enum_parameter_override_pkg;
  typedef enum logic [3:0] {
    MuBiTrue  = 4'h6,
    MuBiFalse = 4'h9
  } mubi_t;
endpackage

module imported_enum_parameter_override_sender #(
  parameter imported_enum_parameter_override_pkg::mubi_t ResetValue =
      imported_enum_parameter_override_pkg::MuBiFalse
);
  initial begin
    if (ResetValue !== imported_enum_parameter_override_pkg::MuBiTrue)
      $fatal(1, "imported enum literal was not a constant parameter actual: %h", ResetValue);
  end
endmodule

module imported_enum_parameter_override_test
  import imported_enum_parameter_override_pkg::mubi_t;
();
  import imported_enum_parameter_override_pkg::MuBiTrue;

  imported_enum_parameter_override_sender #(
    .ResetValue(MuBiTrue)
  ) sender();

  initial begin
    #1;
    $display("PASS: explicitly imported enum literal remains a constant");
  end
endmodule
