// Issue #431: save concatenation selectors when the NBA is scheduled.
module sv_nba_concat_index_snapshot;
  logic [7:0] a;
  logic [7:0] b;
  integer idx;

  initial begin
    a = '0;
    b = '0;
    idx = 1;
    #1;
    {a[idx +: 2], b[idx]} <= 3'b101;
    idx = 4;
    #1;
    if (a !== 8'h04 || b !== 8'h02)
      $fatal(1, "concat NBA target index changed: a=%h b=%h", a, b);
    $display("PASSED");
  end
endmodule
