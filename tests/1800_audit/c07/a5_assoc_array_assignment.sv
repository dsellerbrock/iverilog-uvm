module a5_assoc_array_assignment;
  int a1[string], a2[string];
  initial begin
    $display("BEGIN a5"); $fflush;
    a1 = '{"a":1, "b":2}; a2 = a1; a2["a"] = 9;
    $display("A5 %0d %0d", a1["a"], a2["a"]);
  end
endmodule
