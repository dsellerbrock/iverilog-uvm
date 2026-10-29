module specified;
  timeunit 1ns / 1ps;
endmodule

module unspecified;
endmodule

module sv_mixed_time_scopes_fail_2023;
  specified s();
  unspecified u();
endmodule
