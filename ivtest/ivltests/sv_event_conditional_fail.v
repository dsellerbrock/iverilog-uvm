module test;
  real clock_value;
  logic enable;
  initial @(posedge clock_value iff enable);
endmodule
