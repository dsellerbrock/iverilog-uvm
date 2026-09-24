module blklen_value_child #(parameter int BlkLen = 4);
endmodule

module hierarchical_parameter_value;
  blklen_value_child dut();
  wire [31:0] observed = dut.BlkLen;
  initial begin
    #1;
    if (observed !== 32'd4) $fatal(1, "hierarchical parameter value failed");
    $display("PASS hierarchical parameter value");
    $finish(0);
  end
endmodule
