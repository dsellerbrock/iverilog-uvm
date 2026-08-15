module test;
  logic [7:0] greedy[];
  logic [7:0] ranged[$];
  initial {>>{greedy, ranged with [0 +: 1]}} = 16'h1122;
endmodule
