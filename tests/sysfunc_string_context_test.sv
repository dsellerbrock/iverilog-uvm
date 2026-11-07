// IEEE 1800-2017 6.16: an integral value cast to a string is packed byte-wise,
// and "Values of integral type can be assigned to a string variable, but
// require a cast." System-function calls must receive that string context too.

module sysfunc_string_context_test;
  string value;

  initial begin
    #65;
    value = string'($time());
    if (value != "A") begin
      $display("FAIL: integral system-function string conversion produced '%s'",
               value);
      $finish(1);
    end
    $display("PASS");
  end
endmodule
