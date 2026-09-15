package sv_const_function_generate_pkg;
  function automatic int package_helper(input int value = 3);
    return value + 1;
  endfunction
endpackage

module sv_const_function_generate;
  import sv_const_function_generate_pkg::*;

  function automatic int module_helper(input int value = 5);
    return value + 1;
  endfunction

  localparam int MODULE_VALUE = module_helper();
  localparam int PACKAGE_VALUE = package_helper();

  if (1) begin : generated
    function automatic int runtime_helper(input int value = 7);
      return value + 1;
    endfunction
    initial begin
      if (runtime_helper() != 8 || runtime_helper(10) != 11)
        $fatal(1, "generated runtime function failed");
      if (MODULE_VALUE != 6 || PACKAGE_VALUE != 4)
        $fatal(1, "legal constant controls failed");
      $display("PASSED");
    end
  end
endmodule
