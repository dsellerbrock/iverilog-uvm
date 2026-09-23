package array_parameter_typedef_pattern_pkg;
  typedef bit unsigned [7:0] ascending_bytes_t [1:4];
  typedef bit unsigned [7:0] descending_bytes_t [4:1];

  parameter ascending_bytes_t Indexed =
      '{4:8'h44, 1:8'h11, 3:8'h33, 2:8'h22};
  parameter ascending_bytes_t Positional =
      '{8'ha1, 8'ha2, 8'ha3, 8'ha4};
  parameter ascending_bytes_t Partial =
      '{2:8'h22, default:8'hee};
  parameter ascending_bytes_t Copied = Indexed;
  parameter descending_bytes_t Descending =
      '{1:8'hd1, 4:8'hd4, 2:8'hd2, 3:8'hd3};
endpackage

module main;
  import array_parameter_typedef_pattern_pkg::*;

  initial begin
    if (Indexed[1] !== 8'h11 || Indexed[2] !== 8'h22 ||
        Indexed[3] !== 8'h33 || Indexed[4] !== 8'h44)
      $fatal(1, "keyed typedef array indices were not applied");
    if (Positional[1] !== 8'ha1 || Positional[4] !== 8'ha4)
      $fatal(1, "positional typedef array bounds were not preserved");
    if (Partial[1] !== 8'hee || Partial[2] !== 8'h22 ||
        Partial[4] !== 8'hee)
      $fatal(1, "default key did not fill unassigned indices");
    if (Copied[1] !== 8'h11 ||
        array_parameter_typedef_pattern_pkg::Indexed[4] !== 8'h44)
      $fatal(1, "package-imported array parameter lookup failed");
    if (Descending[1] !== 8'hd1 || Descending[2] !== 8'hd2 ||
        Descending[3] !== 8'hd3 || Descending[4] !== 8'hd4)
      $fatal(1, "descending typedef array bounds were not preserved");
    $display("PASSED");
  end
endmodule
