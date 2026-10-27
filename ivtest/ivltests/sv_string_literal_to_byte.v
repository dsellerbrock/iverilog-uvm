// IEEE 1800-2017/2023 6.16: string literals may initialize byte values and
// assign to a string character; the cast requirement applies to string data.
module sv_string_literal_to_byte;
  byte value = "A";
  string target = "xyz";

  initial begin
    target[0] = "B";
    if (value !== 8'h41 || target != "Byz")
      $fatal(1, "string literal to byte conversion");
    $display("PASSED");
  end
endmodule
