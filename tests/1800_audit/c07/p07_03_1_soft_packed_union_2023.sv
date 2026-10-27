module test;
  typedef union soft packed {
    bit [1:0] low;
    bit [3:0] whole;
  } soft_union_t;

  soft_union_t value;

  initial begin
    value.whole = 4'b1011;
    value.low = 2'b01;
    if (value.whole !== 4'b1001 || value.low !== 2'b01)
      $fatal(1, "soft packed union did not retain upper bits on narrow write");
    $display("PASS 2023 §7.3.1 soft packed union checks");
    $finish;
  end
endmodule
