module a6_assoc_array_args;
  int a1[string], a2[string];
  function automatic void byval(int x[string]); x["a"] = 100; endfunction
  function automatic void byref(ref int x[string]); x["a"] = 200; endfunction
  initial begin
    $display("BEGIN a6"); $fflush;
    a1 = '{"a":1, "b":2}; a2 = a1; a2["a"] = 9;
    $display("A6 copy %0d %0d", a1["a"], a2["a"]);
    byval(a1); $display("A6 byval %0d", a1["a"]);
    byref(a1); $display("A6 ref %0d", a1["a"]);
  end
endmodule
