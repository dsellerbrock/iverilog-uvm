// IEEE 1800-2017 6.16: an integral result assigned to a string is packed
// byte-wise. System-function calls must receive that string context too.

module sysfunc_string_context_test;
  string value;

  initial begin
    #65;
    value = $time();
    if (value != "A") begin
      $display("FAIL: integral system-function string conversion produced '%s'",
               value);
      $finish(1);
    end
    $display("PASS");
  end
endmodule
