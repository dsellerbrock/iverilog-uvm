module typed_arrays;
  integer integers [0:1];
  time times [0:1];
  real reals [0:1];
  wire [7:0] nets [0:1];
  assign nets[0] = 8'h12;
  assign nets[1] = 8'h34;
endmodule

module top;
  reg [7:0] mem [0:1];
  typed_arrays typed();

  initial begin
    mem[0] = 8'h2a;
    mem[1] = 8'hc5;
    $check_memory_types;
    if (mem[1] !== 8'h5c)
      $fatal(1, "VPI write did not reach mem[1]");
  end
endmodule
