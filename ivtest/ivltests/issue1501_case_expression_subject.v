typedef union tagged { void Empty; int Value; } U;

module top;
  U value;
  int calls;
  int result;

  function automatic U get_value();
    calls = calls + 1;
    return value;
  endfunction

  initial begin
    value = tagged Value(7);
    calls = 0;
    case (get_value()) matches
      tagged Empty: result = 0;
      tagged Value: result = 1;
      default: result = 2;
    endcase
    if (calls !== 1) $fatal(1, "calls=%0d", calls);
    if (result !== 1) $fatal(1, "result=%0d", result);

    result = -1;
    case (get_value()) matches
      tagged Value .payload: result = payload;
      tagged Empty: result = 0;
      default: result = 2;
    endcase
    if (calls !== 2) $fatal(1, "calls=%0d", calls);
    if (result !== 7) $fatal(1, "result=%0d", result);
    $display("PASSED");
  end
endmodule
