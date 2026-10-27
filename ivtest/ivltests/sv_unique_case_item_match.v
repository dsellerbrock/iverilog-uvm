module sv_unique_case_item_match;
  bit [2:0] a;
  int duplicate_result;
  int pattern_result;
  int distinct_result;

  initial begin
    a = 1;
    unique case (a)
      1, 1: duplicate_result = 1;
      2:   duplicate_result = 2;
    endcase
    if (duplicate_result !== 1)
      $fatal(1, "duplicate labels in one case_item selected the wrong branch");

    a = 0;
    unique casez (a)
      3'b00?, 3'b0?0: pattern_result = 1;
      default: pattern_result = 2;
    endcase
    if (pattern_result !== 1)
      $fatal(1, "overlapping patterns in one case_item selected the wrong branch");

    a = 1;
    unique case (a)
      1: distinct_result = 1;
      1: distinct_result = 2;
    endcase
    if (distinct_result !== 1)
      $fatal(1, "overlapping case_items did not preserve the first branch");

    $display("PASSED");
  end
endmodule
