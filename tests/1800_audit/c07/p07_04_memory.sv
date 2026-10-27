module test;
  logic [7:0] mem[0:3];
  logic [7:0] read_data;

  initial begin
    mem[2] = 8'hA5;
    read_data = mem[2];
    if (read_data !== 8'hA5)
      $fatal(1, "memory word write/read mismatch");
    $display("PASS §7.4 memory word write/read");
    $finish;
  end
endmodule
