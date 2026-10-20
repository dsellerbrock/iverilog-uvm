module sv_display_explicit_width;
  string actual;

  initial begin
    actual = $sformatf("%3h|%3h|%3h|%02X|%3o|%3b|%h|%0h",
                       32'h5, 32'h100, 32'h1234, 32'h3,
                       32'h5, 32'h5, 32'h5, 32'h5);
    if (actual != "005|100|1234|03|005|101|00000005|5")
      $fatal(1, "explicit radix width: got <%s>", actual);
    $display("PASSED");
  end
endmodule
