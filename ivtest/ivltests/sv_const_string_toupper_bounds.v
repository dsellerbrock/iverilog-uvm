module sv_const_string_toupper_bounds;
  function automatic string upper(input string text);
    string original = text;
    string converted = text.toupper();
    if (text != original) return "BAD-UPPER-MUTATION";
    return converted;
  endfunction
  function automatic string lower(input string text);
    string original = text;
    string converted = text.tolower();
    if (text != original) return "BAD-LOWER-MUTATION";
    return converted;
  endfunction

  localparam string EMPTY = upper("");
  localparam string LOWER_EMPTY = lower("");
  localparam string BYTES = upper("azAZ_09\200\377");
  localparam string LOWER_BYTES = lower("azAZ_09\200\377");
  initial begin
    if (EMPTY != "" || LOWER_EMPTY != "" ||
        BYTES != "AZAZ_09\200\377" ||
        LOWER_BYTES != "azaz_09\200\377")
      $fatal(1, "toupper byte boundary mismatch: size=%0d value=%s",
             EMPTY.len(), BYTES);
    $display("PASSED");
  end
endmodule
