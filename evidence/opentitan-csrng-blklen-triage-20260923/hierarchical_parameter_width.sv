// Released CSRNG shape: an instance-hierarchical parameter is used as an
// indexed part-select width, which IEEE constant_primary does not admit.
module blklen_child #(parameter int BlkLen = 4);
  logic [7:0] storage = 8'hac;
endmodule

module hierarchical_parameter_width;
  blklen_child dut();
  wire [3:0] selected = dut.storage[7 -: dut.BlkLen];
endmodule
