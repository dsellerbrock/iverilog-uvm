module selected_source(output logic [1:0] out);
  assign out = 2'b10;
endmodule

module test;
  logic [3:0] actual;
  selected_source first(actual[2:1]);
  selected_source second(actual[2:1]);
endmodule
