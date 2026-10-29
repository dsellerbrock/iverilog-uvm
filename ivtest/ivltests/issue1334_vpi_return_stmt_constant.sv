module issue1334_vpi_return_stmt_constant;
  function automatic int return_value();
    return 691;
  endfunction

  initial begin
    if (return_value() != 691)
      $fatal(1, "return statement result mismatch");
    $display("PASSED");
    $finish;
  end
endmodule
