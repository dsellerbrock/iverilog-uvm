// IEEE 1800-2023 6.16: "Values of integral type can be assigned to a string
// variable, but require a cast." Every assignment-like context is covered.
module issue733_string_cast_required_fail;
  string s;
  logic [15:0] v = 16'h4142;
  byte b = 8'h41;
  int i = 65;
  parameter NUM = 8'h41;
  function string take(input string x); return x; endfunction
  function string give(); return v; endfunction
  string init = v;
  initial begin
    s = 8'h41;
    s = v;
    s = b;
    s = i + 1;
    s = NUM;
    s = $time;
    s = take(v);
  end
endmodule
