module p35_string_openarray;
  import "DPI-C" function int c_array_size(input string values[]);

  string values[];

  initial begin
    values = new[2];
    values[0] = "first";
    values[1] = "second";
    if (c_array_size(values) != 2)
      $fatal(1, "wrong DPI open-array size");
    $display("PASS string open-array size=2");
    $finish;
  end
endmodule
