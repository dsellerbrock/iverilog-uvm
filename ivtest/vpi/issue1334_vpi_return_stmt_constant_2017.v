module top;
  function automatic integer return_value;
    return 691;
  endfunction

  initial begin
    if (return_value() != 691)
      $fatal(1, "return statement result mismatch");
    $display("PASSED");
    $finish;
  end
endmodule
