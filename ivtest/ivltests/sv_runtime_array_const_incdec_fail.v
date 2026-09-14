module test;
  const int values[2] = '{5,7};
  int result;
  initial begin
    result=values[0]++;
    result=--values[1];
  end
endmodule
