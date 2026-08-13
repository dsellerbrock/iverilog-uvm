// An open range is a case-item value only for `case ... inside`; ordinary
// case items use expressions and must not silently accept a never-match range.
module test;
  int value;
  initial begin
    case (value)
      [1:3]: value = 1;
      default: value = 0;
    endcase
  end
endmodule
