module issue1281_vpi_memory_types;
  reg [7:0] mem [0:1];

  initial begin
    mem[0] = 8'h5a;
    $probe_memory_types;
    $finish;
  end
endmodule
