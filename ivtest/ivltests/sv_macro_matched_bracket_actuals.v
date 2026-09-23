`define SECOND(a, b) b

module sv_macro_matched_bracket_actuals;
  integer array_handle [0:1][0:1];
  integer index_a, index_b;

  initial begin
    index_a = 0;
    index_b = 1;
    if (`SECOND(array_handle[index_a,index_b], 73) != 73) $fatal(1);
    if (`SECOND({1,2}, 74) != 74) $fatal(1);
    if (`SECOND((1,2), 75) != 75) $fatal(1);
    if (`SECOND(({1,2}), 76) != 76) $fatal(1);
    $display("PASS macro matched bracket actuals");
  end
endmodule
