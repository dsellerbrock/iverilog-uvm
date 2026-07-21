// IEEE 1800-2017 7.8.1: associative array with a wildcard index type,
// `type name[*];`. The index type is unspecified (any integral key). This
// declaration form was previously a syntax error — the lexer folds `[*`
// into one token (K_LBSTAR, shared with the SVA consecutive-repetition
// opener), so the parser never saw `[` and `*` separately.
module sv_assoc_wildcard_index;
  int aa[*];
  int errors = 0;
  int seen = 0;
  initial begin
    aa[3]   = 30;
    aa[100] = 1000;
    aa[-7]  = -70;

    if (aa[3]   !== 30)   begin $display("FAIL aa[3]=%0d", aa[3]); errors++; end
    if (aa[100] !== 1000) begin $display("FAIL aa[100]=%0d", aa[100]); errors++; end
    if (aa[-7]  !== -70)  begin $display("FAIL aa[-7]=%0d", aa[-7]); errors++; end
    if (aa.size() !== 3)  begin $display("FAIL size=%0d", aa.size()); errors++; end
    if (!aa.exists(3))    begin $display("FAIL !exists(3)"); errors++; end
    if (aa.exists(5))     begin $display("FAIL exists(5)"); errors++; end

    aa.delete(3);
    if (aa.exists(3))     begin $display("FAIL exists(3) after delete"); errors++; end
    if (aa.size() !== 2)  begin $display("FAIL size after delete=%0d", aa.size()); errors++; end

    foreach (aa[i]) seen++;
    if (seen !== 2) begin $display("FAIL foreach count=%0d", seen); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule
