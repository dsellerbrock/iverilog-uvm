module top;
  int values[*];
  int errors = 0;

  initial begin
    values["A"] = 2;
    values["AB"] = 3;

    if (values.num() !== 2) begin
      $display("FAIL entries=%0d", values.num());
      errors++;
    end
    if (values[8'h41] !== 2) begin
      $display("FAIL 8'h41=%0d", values[8'h41]);
      errors++;
    end
    if (values[32'h41] !== 2) begin
      $display("FAIL 32'h41=%0d", values[32'h41]);
      errors++;
    end
    if (values[16'h4142] !== 3) begin
      $display("FAIL 16'h4142=%0d", values[16'h4142]);
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule
