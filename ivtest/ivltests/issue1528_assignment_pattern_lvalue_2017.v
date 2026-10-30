module top;
  typedef struct packed { logic [7:0] a, b; } P;
  P source;
  logic [7:0] x, y;

  initial begin
    source = '{8'h12, 8'h34};
    '{x, y} = source;
    if (x !== 8'h12 || y !== 8'h34)
      $fatal(1, "LHS_PATTERN expected 12 34, got %h %h", x, y);
    $display("LHS_PATTERN %h %h", x, y);
  end
endmodule
