module top;
  reg [7:0] mem [0:1];

  initial begin
    mem[0] = 8'h12;
    $probe_memory_vpi_types;
    $finish;
  end
endmodule
