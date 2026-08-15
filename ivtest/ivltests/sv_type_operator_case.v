// IEEE 1800-2017 6.23: type() values participate in case matching.
module test #(parameter type T = type(logic [11:0]));
  typedef logic [11:0] word_t;
  bit failed = 0;

  initial begin
    case (type(T))
      type(logic [12:0]): failed = 1;
      type(logic [10:0]), type(word_t): ;
      default: failed = 1;
    endcase

    // Equivalent type items obey ordinary first-match ordering.
    case (type(T))
      type(word_t): ;
      type(logic [11:0]): failed = 1;
      default: failed = 1;
    endcase

    // A nonmatching type selects default.
    case (type(logic [13:0]))
      type(T): failed = 1;
      default: ;
    endcase

    if (type(T) == type(logic [12:0])) failed = 1;
    if (type(T) != type(logic [11:0])) failed = 1;
    if (type(T) === type(logic [12:0])) failed = 1;
    if (type(T) !== type(logic [11:0])) failed = 1;

    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
