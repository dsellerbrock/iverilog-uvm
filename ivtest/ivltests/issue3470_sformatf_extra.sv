module issue3470_sformatf_extra;
  string fmt, result;
  reg [8*4-1:0] packed_fmt;
  initial begin
    fmt = "%0d-%h";
    result = $sformatf(fmt, 12, 8'hab, 3);
    if (result != "12-ab") $fatal(1, "extra numeric: [%s]", result);
    result = $sformatf("literal %% %0d", 7, "%0d", 9);
    if (result != "literal % 7") $fatal(1, "extra string: [%s]", result);
    packed_fmt = "%0d";
    result = $sformatf(packed_fmt, 5, 6);
    if (result != "5") $fatal(1, "packed format: [%s]", result);
    result = $sformatf("%% %0d", 4);
    if (result != "% 4") $fatal(1, "exact arguments: [%s]", result);
    result = $sformatf("plain");
    if (result != "plain") $fatal(1, "no arguments: [%s]", result);
    $display("PASS");
  end
endmodule
