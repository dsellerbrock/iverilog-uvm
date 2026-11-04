typedef union tagged {
  void Invalid;
  int Value;
} Inner;

typedef union tagged {
  void None;
  Inner Nested;
} Outer;

typedef union tagged packed {
  int Other;
  int Value;
} PackedInner;

typedef union tagged packed {
  bit [32:0] Other;
  PackedInner Nested;
} PackedOuter;

module top;
  function automatic Inner make_inner(input int payload);
    make_inner = tagged Value(payload);
  endfunction

  Outer value;
  Inner copied_inner;
  PackedOuter packed_value;
  int result;

  task automatic check_pattern(input int expected, input bit should_match);
    result = -1;
    case (value) matches
      tagged Nested tagged Value .n: result = n;
      default: ;
    endcase
    if (should_match) begin
      if (result !== expected)
        $fatal(1, "expected %0d, got %0d", expected, result);
    end else if (result !== -1) begin
      $fatal(1, "inactive nested tag matched with %0d", result);
    end
  endtask

  initial begin
    value = tagged Nested(tagged Value(9));
    check_pattern(9, 1'b1);

    value = tagged Nested(make_inner(17));
    check_pattern(17, 1'b1);

    copied_inner = value.Nested;
    value = tagged Nested(copied_inner);
    check_pattern(17, 1'b1);

    value = tagged Nested(tagged Invalid);
    check_pattern(-1, 1'b0);

    packed_value = tagged Nested(tagged Value(21));
    result = -1;
    case (packed_value) matches
      tagged Nested tagged Value .n: result = n;
      default: ;
    endcase
    if (result !== 21)
      $fatal(1, "packed nested pattern expected 21, got %0d", result);

    $display("PASSED");
  end
endmodule
