// Host-sized constant range arithmetic must not overflow while diagnosing.
module test;
  logic [7:0] fixed[4:2];
  initial {>>{fixed with [64'sh7fff_ffff_ffff_ffff
                          +: 64'sh7fff_ffff_ffff_ffff]}} = 8'h00;
endmodule
