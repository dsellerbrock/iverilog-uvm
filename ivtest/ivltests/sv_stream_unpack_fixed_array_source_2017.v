// Streaming unpack from a fixed unpacked array source (IEEE 1800-2017
// 11.4.14.3).
module main;
  logic [10:0] up [3:0];
  logic [11:1] p1, p2, p3, p4;

  initial begin
    up[0] = 11'd1;
    up[1] = 11'd2;
    up[2] = 11'd3;
    up[3] = 11'd4;
    { >> {p1, p2, p3, p4}} = up;
    if (p1 !== 11'd4 || p2 !== 11'd3 || p3 !== 11'd2 || p4 !== 11'd1)
      $fatal(1, "stream unpack from array source: %0d %0d %0d %0d",
             p1, p2, p3, p4);
    $display("PASSED");
  end
endmodule
