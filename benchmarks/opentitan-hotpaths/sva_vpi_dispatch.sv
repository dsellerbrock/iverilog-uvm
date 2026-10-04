module top;
  reg signal;
  integer enabled;
  integer i;
  integer enabled_checks;
  integer clock_calls;

  initial begin
    signal = 0;
    enabled_checks = 0;
    clock_calls = 0;
    $install_sva_vpi_callback();
    for (i = 0; i < 1000; i = i + 1) begin
      enabled = $ivl_sva_enabled(3);
      if (enabled !== 1) $fatal(1, "$ivl_sva_enabled returned disabled");
      enabled_checks = enabled_checks + 1;
      $ivl_assert_clock(3);
      clock_calls = clock_calls + 1;
      signal = ~signal;
      #1;
    end
    $report_sva_vpi_callbacks(1000);
    $display("PASS sva_vpi_dispatch enabled_calls=%0d clock_calls=%0d", enabled_checks, clock_calls);
    $finish;
  end
endmodule
