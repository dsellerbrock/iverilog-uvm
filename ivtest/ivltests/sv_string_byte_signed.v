// IEEE 1800-2017/2023 6.16, 6.16.3 and 6.11.3: indexed string character is byte.
module sv_string_byte_signed;
  string s, array[2];
  integer idx, calls, actual;
  function automatic int echo(input int value);
    return value;
  endfunction
  function automatic int select_index();
    calls++;
    return 0;
  endfunction
  initial begin
    s = "\377\200A"; array[1] = s;
    idx = 0; calls = 0;
    actual = s[0];
    if (actual !== -1 || s[0] !== s.getc(0)) $fatal(1, "constant signed byte");
    actual = s[idx];
    if (actual !== -1 || s[idx] + 2 !== 1) $fatal(1, "variable arithmetic");
    if (echo(s[1]) !== -128 || !(s[1] < 0)) $fatal(1, "formal and comparison");
    if (s[select_index()] !== -1 || calls !== 1) $fatal(1, "single index evaluation");
    if (array[1][idx] !== -1) $fatal(1, "string array element");
    if (s[2] !== 65 || $bits(s[0]) !== 8) $fatal(1, "ASCII and width");
    idx = -1;
    if (s[idx] !== 0 || s[3] !== 0) $fatal(1, "out of range");
    s = "";
    if (s[0] !== 0) $fatal(1, "empty");
    $display("PASSED");
  end
endmodule
