module dpi_export_generate_scope_test;
  import "DPI-C" context function int run_generate_export_test();

  if (1) begin : gen_dpi
    export "DPI-C" function simutil_get_scramble_key;
    function automatic int simutil_get_scramble_key(output bit [127:0] val);
      val = 128'h01234567_89abcdef_fedcba98_76543210;
      return 7;
    endfunction
  end

  initial begin
    if (run_generate_export_test() != 0)
      $fatal(1, "generated-scope DPI export copy-out failed");
    $display("PASS: generated-scope DPI export packed-vector copy-out");
    $finish;
  end
endmodule
