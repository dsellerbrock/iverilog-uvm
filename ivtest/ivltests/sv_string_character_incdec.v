module sv_string_character_incdec;
  string text = "ABC";
  int calls;
  byte old_value, new_value;
  function automatic int idx(); calls++; return 1; endfunction
  initial begin
    old_value = text[idx()]++;
    new_value = --text[2];
    if (text != "ACB" || old_value != 66 || new_value != 66 || calls != 1)
      $fatal(1, "text=%s old=%0d new=%0d calls=%0d", text, old_value, new_value, calls);
    old_value = text[0]--;
    new_value = ++text[0];
    if (text != "ACB" || old_value != 65 || new_value != 65)
      $fatal(1, "pre/post decrement mismatch");
    $display("PASSED");
  end
endmodule
