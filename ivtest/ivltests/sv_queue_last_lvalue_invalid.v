module test;
  int dynamic_values[];
  int associative_values[int];
  bit [7:0] vector_value;
  initial begin
    dynamic_values[$]=1;
    associative_values[$]=2;
    vector_value[$]=1'b1;
  end
endmodule
