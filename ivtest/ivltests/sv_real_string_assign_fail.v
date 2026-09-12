// Check that assigning a string value to a real variable is rejected.
// IEEE 1800-2017/2023 6.16 defines only string<->integral and
// string<->string implicit conversions; there is no implicit
// string-to-real conversion. This previously compiled clean and
// silently substituted 0.0, discarding the string value (L35).

module test;

  real r;
  string s;

  initial begin
    s = "3.5";
    r = s;
    $display("FAILED");
  end

endmodule
