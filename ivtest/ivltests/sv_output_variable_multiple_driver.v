module source_one(output logic out);
  assign out = 1'b1;
endmodule

module test;
  logic value;
  source_one first(value);
  source_one second(value);
endmodule
