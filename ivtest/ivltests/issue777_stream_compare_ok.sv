module issue777_stream_compare_ok;
  bit [7:0] a[4];
  bit [31:0] result;
  initial begin
    a[0] = 8'haa; a[1] = 8'hbb; a[2] = 8'hcc; a[3] = 8'hdd;
    result = {<<byte{a}};
    if (result !== 32'hddccbbaa ||
        int'({<<byte{a}}) != 32'hddccbbaa ||
        32'hddccbbaa != int'({<<byte{a}})) $fatal(1, "FAIL");
    $display("PASS");
  end
endmodule
