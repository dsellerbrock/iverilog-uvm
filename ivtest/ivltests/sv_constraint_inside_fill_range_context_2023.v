module main;
  bit [31:0] value;

  initial begin
    if (!std::randomize(value) with {
      value inside {[32'd100000:'1]};
      value == 32'hffff_ffff;
    }) $fatal(1, "full-width upper endpoint rejected");
    if (value !== 32'hffff_ffff) $fatal(1, "upper endpoint mismatch");

    if (!std::randomize(value) with {
      value inside {[32'd100000:'1]};
      value == 32'd100000;
    }) $fatal(1, "lower endpoint rejected");
    if (value !== 32'd100000) $fatal(1, "lower endpoint mismatch");

    $display("PASSED");
  end
endmodule
