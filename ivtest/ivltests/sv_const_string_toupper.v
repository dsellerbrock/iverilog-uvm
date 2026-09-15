module sv_const_string_toupper;
  function automatic string upper(input string text);
    string local_text;
    string original;
    string converted;
    local_text = text;
    original = local_text;
    converted = local_text.toupper();
    if (local_text != original) return "BAD-UPPER-MUTATION";
    return converted;
  endfunction
  function automatic string lower(input string text);
    string original;
    string converted;
    original = text;
    converted = text.tolower();
    if (text != original) return "BAD-LOWER-MUTATION";
    return converted;
  endfunction

  localparam string MIXED = upper("aZ-09!?z");
  localparam string AGAIN = upper(upper("repeat"));
  localparam string LOWER = lower("Az-09!?Z");
  initial begin
    string runtime_text;
    string runtime_lower;
    runtime_text = "aZ-09!?z";
    runtime_lower = "Az-09!?Z";
    if (MIXED != "AZ-09!?Z" || AGAIN != "REPEAT" ||
        LOWER != "az-09!?z" || runtime_text.toupper() != MIXED ||
        runtime_lower.tolower() != LOWER || runtime_text != "aZ-09!?z" ||
        runtime_lower != "Az-09!?Z")
      $fatal(1, "constant/runtime toupper mismatch: %s/%s/%s",
             MIXED, AGAIN, runtime_text);
    $display("PASSED");
  end
endmodule
