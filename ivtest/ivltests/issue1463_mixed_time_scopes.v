module issue1463_specified;
  timeunit 1ns / 1ps;
endmodule

module issue1463_unspecified;
endmodule

module issue1463_mixed_time_scopes;
  issue1463_specified specified();
  issue1463_unspecified unspecified();
endmodule
