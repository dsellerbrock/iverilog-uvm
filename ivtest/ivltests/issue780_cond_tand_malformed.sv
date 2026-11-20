module issue780_cond_tand_malformed;
  int subject, result;
  initial begin
    result = 1 ? (subject matches .a &&& a matches .b ? : 0) : 0;
  end
endmodule
