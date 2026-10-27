// IEEE 1800-2017/2023 7.12.2 prohibits with clauses on reverse and shuffle.
module sv_array_order_with_fail;
  int values[] = '{1, 2};
  initial begin
    values.reverse with (item);
    values.shuffle with (item);
  end
endmodule
