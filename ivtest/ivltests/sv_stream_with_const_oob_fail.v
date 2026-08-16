module test;
  logic [7:0] fixed[4:2];
  initial {>>{fixed with [1 +: 3]}} = 24'h112233;
endmodule
