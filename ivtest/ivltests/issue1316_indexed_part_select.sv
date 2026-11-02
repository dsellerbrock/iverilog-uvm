module top;
  logic [15:0] data = 42330;
  integer base = 4;
  integer negbase = 7;
  initial begin
    $selectprobe(data[base +: 4]);
    $selectprobe(data[negbase -: 4]);
    $selectprobe(data[4 +: 4]);
    $finish;
  end
endmodule
