module sv_const_local_array_pattern;
  function automatic string checked;
    string words[2] = '{"abc", "def"};
    const string frozen[2] = '{"m", "n"};
    words = '{"ghi", "jkl"};
    if (frozen[0] != "m" || frozen[1] != "n") return "BAD";
    return {words[0], words[1]};
  endfunction
  localparam string VALUE = checked();
  initial begin
    if (VALUE != "ghijkl" || checked() != "ghijkl")
      $fatal(1, "local string array pattern mismatch");
    $display("PASSED");
  end
endmodule
