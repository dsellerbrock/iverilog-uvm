module issue912_timezero_sample;
  bit c0 = 0;
  logic declaration_default = 0;
  logic type_default;
  integer results = 0;

  initial begin
    declaration_default = 1;
    type_default = 1;
  end

  initial #0 c0 = 1;

  // IEEE 1800-2017/2023 16.5.1: static variables use their default
  // sampled values in the time-zero slot, before either initial write.
  assert property (@(posedge c0) declaration_default)
    $display("UNEXPECTED_DECLARATION_DEFAULT");
  else begin
    $display("DECLARATION_DEFAULT_ZERO");
    results++;
  end

  assert property (@(posedge c0) type_default === 1'bx)
    begin
      $display("TYPE_DEFAULT_X");
      results++;
    end
  else
    $display("UNEXPECTED_TYPE_DEFAULT");

  initial begin
    #1;
    if (results != 2)
      $fatal(1, "time-zero sampled-value checks=%0d, expected 2", results);
    $display("PASSED");
  end
endmodule
