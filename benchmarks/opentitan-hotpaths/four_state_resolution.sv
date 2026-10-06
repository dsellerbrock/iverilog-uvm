module top;
  tri [7:0] resolved;
  reg [7:0] driver_a;
  reg [7:0] driver_b;
  integer i;
  integer checks;

  assign resolved = driver_a;
  assign resolved = driver_b;

  initial begin
    driver_a = 8'hzz;
    driver_b = 8'hzz;
    checks = 0;
    for (i = 0; i < 2000; i = i + 1) begin
      driver_a = 8'h00;
      driver_b = 8'hff;
      #1;
      if (resolved !== 8'hxx) $fatal(1, "conflict did not resolve to X");
      checks = checks + 1;

      driver_a = 8'hzz;
      driver_b = (i[0] ? 8'ha5 : 8'h5a);
      #1;
      if (resolved !== driver_b) $fatal(1, "Z driver did not yield to active driver");
      checks = checks + 1;

      driver_b = 8'hzz;
      #1;
      if (resolved !== 8'hzz) $fatal(1, "two Z drivers did not resolve to Z");
      checks = checks + 1;

      driver_a = i[0] ? 8'hff : 8'h00;
      driver_b = driver_a;
      #1;
      if (resolved !== driver_a) $fatal(1, "matching drivers changed value");
      checks = checks + 1;
    end
    $display("PASS four_state_resolution cycles=%0d checks=%0d", i, checks);
    $finish;
  end
endmodule
