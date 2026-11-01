typedef union tagged {
  void Invalid;
  int Valid;
} value_t;

module top;
  value_t value;
  int x, y, result;

  initial begin
    value = tagged Valid(5);
    y = 1;

    case (value) matches
      tagged Valid .n &&& (n > 3): result = 2;
      default: result = 3;
    endcase
    if (result !== 2) $fatal(1, "bound filter result=%0d", result);

    case (value) matches
      tagged Valid .n &&& n > 7: result = 1;
      tagged Valid .n &&& (n > 3): result = 2;
      default: result = 3;
    endcase
    if (result !== 2) $fatal(1, "false filter fallthrough result=%0d", result);

    case (value) matches
      tagged Valid .* &&& (y > 0): result = 4;
      default: result = 5;
    endcase
    if (result !== 4) $fatal(1, "wildcard filter result=%0d", result);

    x = 5;
    case (x) matches
      5 &&& (y > 0): result = 6;
      default: result = 7;
    endcase
    if (result !== 6) $fatal(1, "constant filter result=%0d", result);

    $display("PASS");
  end
endmodule
