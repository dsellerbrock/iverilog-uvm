module top;
  typedef union tagged { void Invalid; int Valid; } VInt;
  VInt value;
  int result;

  initial begin
    value = tagged Valid(5);
    result = 0;
    case (value) matches
      (tagged Valid .x): result = x;
      default: result = -1;
    endcase
    if (result !== 5)
      $fatal(1, "parenthesized pattern: %0d", result);
    $display("PASS parenthesized pattern");
    $finish;
  end
endmodule
