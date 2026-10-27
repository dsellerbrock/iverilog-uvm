module sv_std_randomize_zero_arg_checker;
  int a = 1;
  int b = 2;
  int failures = 0;

  initial begin
    std::randomize() with { a < b; };
    if (a != 1 || b != 2) begin
      $display("FAIL statement checker changed variables");
      failures++;
    end
    if (std::randomize() with { a < b; b == 2; } !== 1) begin
      $display("FAIL satisfied constraints");
      failures++;
    end
    if (a != 1 || b != 2) begin
      $display("FAIL satisfied checker changed variables");
      failures++;
    end
    if (std::randomize() with { a < b; b == 3; } !== 0) begin
      $display("FAIL unsatisfied constraints");
      failures++;
    end
    if (a != 1 || b != 2) begin
      $display("FAIL unsatisfied checker changed variables");
      failures++;
    end

    if (failures) $fatal(1, "zero-argument scope randomize checker failed");
    $display("PASS");
  end
endmodule
