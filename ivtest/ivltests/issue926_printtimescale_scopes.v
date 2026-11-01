timeunit 100ps / 10fs;

module a_dat;
  timeunit 1ms / 1us;
  initial begin
    $printtimescale($root);
    $printtimescale($unit);
    $printtimescale();
    $printtimescale(b_dat.c1);
  end
endmodule

`timescale 10 fs / 1 fs
module b_dat;
  c_dat c1();
endmodule

`timescale 1 ns / 1 ns
module c_dat;
endmodule
