module source_one(output logic out);
  assign out = 1'b1;
endmodule

module test;
  logic value = 1'b0;
  source_one source(value);
endmodule
