`begin_keywords "1800-2012"

module main;
  wire [11:0] exact_hits;
  wire [11:0] range_hits;

  // Caliptra uses a genvar membership test to select two responder slots.
  // Both the single-value list and a differently sized range must fold while
  // generate scopes are elaborated.
  generate
    for (genvar index = 0; index < 12; index++) begin : responders
      if (index inside {8, 9})
        assign exact_hits[index] = 1'b1;
      else
        assign exact_hits[index] = 1'b0;

      if (index inside {[3'd2:5'd4]})
        assign range_hits[index] = 1'b1;
      else
        assign range_hits[index] = 1'b0;
    end
  endgenerate

  initial begin
    #1;
    if (exact_hits !== 12'b0011_0000_0000 ||
        range_hits !== 12'b0000_0001_1100) begin
      $display("FAILED -- constant inside generate exact=%b range=%b",
               exact_hits, range_hits);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
