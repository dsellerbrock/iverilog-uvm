module issue1229_assignment_concat_expr;
  logic [3:0] high, low;
  logic [7:0] result;

  initial begin
    high = 4'h0;
    low = 4'h0;
    result = ({high, low} = 8'hA5);
    if (high !== 4'hA || low !== 4'h5 || result !== 8'hA5)
      $fatal(1, "concatenation assignment expression: high=%h low=%h result=%h",
             high, low, result);
    $display("PASSED");
  end
endmodule
