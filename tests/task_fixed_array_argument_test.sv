// IEEE 1800-2017 13.5.1: a whole fixed unpacked array is a legal input
// actual for an equivalent fixed unpacked-array formal.
module task_fixed_array_argument_test;
  bit [7:0][31:0] key[2];
  int calls;

  task automatic consume(input bit [7:0][31:0] value[2]);
    if (value[0][0] == 32'h1234_5678
        && value[1][7] == 32'hdead_beef)
      calls++;
  endtask

  initial begin
    key = '{default: '0};
    key[0][0] = 32'h1234_5678;
    key[1][7] = 32'hdead_beef;
    consume(key);
    if (calls == 1)
      $display("PASS: task fixed-array whole argument");
    else
      $display("FAIL: task fixed-array whole argument calls=%0d", calls);
    $finish;
  end
endmodule
