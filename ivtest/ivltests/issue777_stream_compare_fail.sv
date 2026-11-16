module issue777_stream_compare_fail;
  bit [7:0] a[4];
  initial begin
    if ({<<byte{a}} == 32'hddccbbaa) $display("bad");
    if (32'hddccbbaa == {<<byte{a}}) $display("bad");
    if ({<<byte{a}} != 32'hddccbbaa) $display("bad");
    if (32'hddccbbaa != {<<byte{a}}) $display("bad");
    if ({<<byte{a}} === 32'hddccbbaa) $display("bad");
    if (32'hddccbbaa !== {<<byte{a}}) $display("bad");
    if ({<<byte{a}} < 32'hddccbbaa) $display("bad");
    if (32'hddccbbaa >= {<<byte{a}}) $display("bad");
  end
endmodule
