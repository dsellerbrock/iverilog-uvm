`begin_keywords "1800-2012"

// IEEE 1800-2017 11.5.1: writing an indexed part-select whose base contains
// X or Z has no effect. In a packed concatenation l-value, that discarded
// property slice must not prevent an ordinary sibling slice from updating.
// Immediate X/Z offsets must not be converted to integer zero and silently
// alias the low bits of the class property.
class concat_unknown_offset_c;
  logic [7:0] value;
endclass

module sv_concat_object_lvalue_unknown_offset;
  concat_unknown_offset_c obj;
  logic [3:0] sibling;
  int fails;
  int rhs_calls;

  function automatic logic [7:0] evaluated_rhs(input logic [7:0] value);
    rhs_calls++;
    return value;
  endfunction

  initial begin
    obj = new;
    fails = 0;
    rhs_calls = 0;

    // The property is source-leftmost and receives the high nibble. Its
    // unknown select discards that slice; the right sibling still receives 3.
    obj.value = 8'ha5;
    sibling = 4'h0;
    {obj.value[2'bx +: 4], sibling} = evaluated_rhs(8'hc3);
    if (obj.value !== 8'ha5 || sibling !== 4'h3 || rhs_calls != 1) begin
      $display("FAILED X mixed offset: value=%h sibling=%h calls=%0d",
               obj.value, sibling, rhs_calls);
      fails++;
    end

    // Reverse the concatenation order and use Z. The property now receives
    // the low nibble, while the left sibling must still receive the high one.
    obj.value = 8'h5a;
    sibling = 4'h0;
    {sibling, obj.value[2'bz +: 4]} = evaluated_rhs(8'h6d);
    if (obj.value !== 8'h5a || sibling !== 4'h6 || rhs_calls != 2) begin
      $display("FAILED Z mixed offset: value=%h sibling=%h calls=%0d",
               obj.value, sibling, rhs_calls);
      fails++;
    end

    // The adjacent single-property blocking-assignment path has the same
    // immediate-index boundary. The destination write remains a no-op, but
    // the RHS function must still execute exactly once for each statement.
    obj.value = 8'ha5;
    obj.value[1'bx] = evaluated_rhs(8'h00);
    if (obj.value !== 8'ha5 || rhs_calls != 3) begin
      $display("FAILED standalone X index: value=%h calls=%0d",
               obj.value, rhs_calls);
      fails++;
    end

    obj.value = 8'h5a;
    obj.value[1'bz] = evaluated_rhs(8'h01);
    if (obj.value !== 8'h5a || rhs_calls != 4) begin
      $display("FAILED standalone Z index: value=%h calls=%0d",
               obj.value, rhs_calls);
      fails++;
    end

    if (fails == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED (%0d cases)", fails);
  end
endmodule

`end_keywords
