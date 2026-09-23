`define SECOND(a, b) b

module sv_macro_actual_delimiter_boundaries;
  initial begin
    if (`SECOND("comma, and close )", 73) != 73) $fatal(1);
    if (`SECOND(1 /* comma, close ) and mismatched } ] */, 74) != 74) $fatal(1);
    if (`SECOND(int'('1), 75) != 75) $fatal(1);
    $display("PASS macro actual delimiter boundaries");
  end
endmodule
