module issue1259_alloc_scheme;
  integer x = 42;
  initial begin
    $probe_alloc_scheme;
    $finish;
  end
endmodule
