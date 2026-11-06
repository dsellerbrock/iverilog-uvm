typedef union tagged { void Empty; int Value; } U;

module top;
  U value;
  int calls;
  int result;
  int payload_result;

  function automatic U get_value();
    calls++;
    return value;
  endfunction

  initial begin
    value = tagged Value(7);
    case (get_value()) matches
      tagged Empty: result = 0;
      tagged Value: result = 1;
      default: result = 2;
    endcase

    if (result !== 1)
      $fatal(1, "unexpected pattern result %0d", result);
    if (calls !== 1)
      $fatal(1, "subject function called %0d times", calls);

    calls = 0;
    case (get_value()) matches
      tagged Value .payload: payload_result = payload;
      default: payload_result = -1;
    endcase
    if (payload_result !== 7)
      $fatal(1, "unexpected captured payload %0d", payload_result);
    if (calls !== 1)
      $fatal(1, "binding subject function called %0d times", calls);
    $display("PASS expression case subject, calls=%0d", calls);
  end
endmodule
