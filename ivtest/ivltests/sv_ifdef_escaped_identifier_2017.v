`define \foo 1
`define \name+with.punctuation 1

module test;
  initial begin
`ifdef \foo
    $display("PASS: ifdef defined");
`else
    $display("FAIL: ifdef defined");
`endif

`ifndef \missing
    $display("PASS: ifndef undefined");
`else
    $display("FAIL: ifndef undefined");
`endif

`ifndef \foo
    $display("FAIL: ifndef defined");
`else
    $display("PASS: ifndef defined");
`endif

`ifdef \missing
    $display("FAIL: elsif false first branch");
`elsif \name+with.punctuation
    $display("PASS: elsif escaped punctuation name");
`else
    $display("FAIL: elsif escaped punctuation name");
`endif
  end
endmodule
