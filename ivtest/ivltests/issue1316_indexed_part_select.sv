module top;
  logic [15:0] data = 42330;
  integer base = 4;

  initial begin
    $selectprobe(data[base +: 4]);
    $selectprobe(data[7:4]);
    $finish;
  end
endmodule
