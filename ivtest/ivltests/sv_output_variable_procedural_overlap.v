module source_one(output logic out);
  assign out = 1'b1;
endmodule

module test;
  logic value;
  source_one source(value);
  initial value = 1'b0;
endmodule
