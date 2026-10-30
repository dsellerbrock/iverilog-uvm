// IEEE 1800-2017 10.9: positional assignment pattern as an l-value.
module test;
  typedef struct packed { logic [7:0] a, b; } P;
  P source;
  logic [7:0] x, y;

  initial begin
    source = '{8'h12, 8'h34};
    '{x, y} = source;
    if (x !== 8'h12 || y !== 8'h34)
      $fatal(1, "positional assignment-pattern l-value failed: %h %h", x, y);
    $display("LHS_PATTERN %h %h", x, y);
  end
endmodule
