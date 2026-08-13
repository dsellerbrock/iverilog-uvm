// IEEE 1800-2017 12.5.4: one `case ... inside` item is an open-value-
// range list, so values, wildcard values, and ranges may be comma-mixed.
module test;
  int errors = 0;

  function automatic int classify(input logic [3:0] value);
    case (value) inside
      4'd1, [4'd3:4'd4], 4'd6: classify = 10;
      4'b10??, [4'd12:4'd13]: classify = 20;
      [4'd14:$]: classify = 40;
      default classify = 30;
    endcase
  endfunction

  initial begin
    for (int value = 0; value < 16; value += 1) begin
      int expected;
      if (value == 1 || value == 3 || value == 4 || value == 6)
        expected = 10;
      else if (value >= 8 && value <= 13)
        expected = 20;
      else if (value >= 14)
        expected = 40;
      else
        expected = 30;
      if (classify(value) != expected) begin
        errors += 1;
        $display("FAILED value=%0d got=%0d expected=%0d",
                 value, classify(value), expected);
      end
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED: %0d classifications", errors);
  end
endmodule
