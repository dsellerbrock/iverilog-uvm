module test;
  logic [7:0] data[];
  logic [7:0] value;
  initial value = {>>{data with [0 +: ]}};
endmodule
