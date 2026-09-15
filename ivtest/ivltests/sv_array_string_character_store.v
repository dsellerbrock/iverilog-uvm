module sv_array_string_character_store;
  string values[3:2];
  int word_calls, character_calls, rhs_calls;
  function automatic int word_once(input int value); word_calls++; return value; endfunction
  function automatic int character_once(input int value); character_calls++; return value; endfunction
  function automatic byte rhs_once(input byte value); rhs_calls++; return value; endfunction
  task automatic update_local;
    string local_values[-1:0];
    local_values[-1] = "DEF";
    local_values[0] = "ABC";
    local_values[-1][2] = "Z";
    if (local_values[-1] != "DEZ" || local_values[0] != "ABC")
      $fatal(1, "automatic local array store");
  endtask
  initial begin
    values[3] = "DEF"; values[2] = "ABC";
    values[word_once(2)][character_once(1)] = rhs_once("Z");
    if (values[3] != "DEF" || values[2] != "AZC"
        || word_calls != 1 || character_calls != 1 || rhs_calls != 1)
      $fatal(1, "declared range/store mismatch");
    update_local();
    $display("PASSED");
  end
endmodule
