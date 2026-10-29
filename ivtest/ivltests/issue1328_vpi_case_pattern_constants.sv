module top;
  initial begin
    #1;
    $probe_case_pattern_constants;
    $finish;
  end
endmodule
