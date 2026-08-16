module test;
  logic [7:0] data[];
  real first;
  initial {>>{data with [first +: 2]}} = 16'h1122;
endmodule
