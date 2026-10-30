`define COMMENTED(a) a /* macro comment
newline continues */ \
+ 1
module issue1558_multiline_comment_macro;
  initial begin
    if (`COMMENTED(4) != 5) $fatal(1, "multiline comment macro value");
    $display("PASS multiline comment in macro");
    $display("PASSED");
  end
endmodule
