// IEEE 1800-2017/2023 §10.4.2; issue #431.
module issue431;
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
      $fatal(1, "target index was not snapshotted: a=%h b=%h", a, b);
    $display("PASS: concat NBA snapshots selected targets");
    $display("PASSED");
  end
endmodule
