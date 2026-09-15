module sv_nested_packed_incdec_bounds;
  logic [1:0][7:0] value;
  logic [127:0] huge;
  logic [3:0] result;
  logic unknown_base;
  bit [1:0][7:0] two_state;

  initial begin
    value = 16'ha55a;
    result = value[1][3:0]++;
    if (result !== 4'h5 || value !== 16'ha65a)
      $fatal(1, "in-bounds mismatch value=%h result=%b", value, result);
    value = 16'ha55a;
    result = value[1][6+:4]++;
    if (result !== 4'bxx10 || value !== 16'bxx100101_01011010)
      $fatal(1, "partial carrier overlap mismatch value=%b result=%b", value, result);
    huge = {128{1'b1}};
    result = value[huge][huge+:4]++;
    if (value !== 16'bxx100101_01011010 || result !== 4'bxxxx)
      $fatal(1, "wide unsigned invalid offset aliased value=%h result=%b", value, result);
    two_state = 16'h1234;
    unknown_base = 1'bx;
    result = ++two_state[1][unknown_base+:4];
    if (result !== 4'h1 || two_state !== 16'h1234)
      $fatal(1, "two-state invalid select mismatch value=%h result=%b", two_state, result);
    $display("PASSED");
  end
endmodule
