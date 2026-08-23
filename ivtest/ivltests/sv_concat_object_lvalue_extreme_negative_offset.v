`begin_keywords "1800-2012"

// Extreme negative offsets in a packed concatenation must discard exactly the
// affected property slice. Ordinary siblings still update, the RHS executes
// once, and a representable -1 base still performs its partial overlap.
class concat_extreme_negative_c;
  logic [7:0] value;
endclass

module sv_concat_object_lvalue_extreme_negative_offset;
  concat_extreme_negative_c obj;
  logic [3:0] sibling;
  int fails;
  int rhs_calls;

  function automatic logic [5:0] evaluated_rhs(input logic [5:0] value);
    rhs_calls++;
    return value;
  endfunction

  initial begin
    obj = new;
    fails = 0;
    rhs_calls = 0;

    obj.value = 8'ha4;
    sibling = 4'h0;
    {obj.value[64'sh8000_0000_0000_0000 +: 2], sibling} =
          evaluated_rhs(6'b11_0101);
    if (obj.value !== 8'ha4 || sibling !== 4'h5 || rhs_calls != 1) begin
      $display("FAILED property-left INT64_MIN: value=%h sibling=%h calls=%0d",
               obj.value, sibling, rhs_calls);
      fails++;
    end

    obj.value = 8'h5a;
    sibling = 4'h0;
    {sibling, obj.value[65'sh1_0000_0000_0000_0000 +: 2]} =
          evaluated_rhs(6'b1010_11);
    if (obj.value !== 8'h5a || sibling !== 4'ha || rhs_calls != 2) begin
      $display("FAILED property-right below INT64_MIN: value=%h sibling=%h calls=%0d",
               obj.value, sibling, rhs_calls);
      fails++;
    end

    obj.value = 8'ha4;
    sibling = 4'h0;
    {obj.value[64'shffff_ffff_ffff_ffff +: 2], sibling} =
          evaluated_rhs(6'b10_0011);
    if (obj.value !== 8'ha5 || sibling !== 4'h3 || rhs_calls != 3) begin
      $display("FAILED negative overlap: value=%h sibling=%h calls=%0d",
               obj.value, sibling, rhs_calls);
      fails++;
    end

    obj.value = 8'h96;
    sibling = 4'h0;
    {obj.value[32'hffff_ffff +: 2], sibling} = evaluated_rhs(6'b11_0110);
    if (obj.value !== 8'h96 || sibling !== 4'h6 || rhs_calls != 4) begin
      $display("FAILED UINT32_MAX: value=%h sibling=%h calls=%0d",
               obj.value, sibling, rhs_calls);
      fails++;
    end

    if (fails == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED (%0d cases)", fails);
  end
endmodule

`end_keywords
