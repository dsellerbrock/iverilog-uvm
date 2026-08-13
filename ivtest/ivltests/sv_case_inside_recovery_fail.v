// Malformed ordinary and inside case items must recover to a null item and
// diagnose; neither case-items vector may retain an uninitialized pointer.
module test;
  int value;
  initial begin
    case (value)
      1, : value = 1;
      default: value = 0;
    endcase
    case (value) inside
      2, : value = 2;
      default: value = 0;
    endcase
  end
endmodule
