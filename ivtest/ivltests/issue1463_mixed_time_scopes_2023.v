module specified;
  timeunit 1ns / 1ps;
endmodule

module unspecified;
endmodule

module tb;
  specified s();
  unspecified u();
endmodule
