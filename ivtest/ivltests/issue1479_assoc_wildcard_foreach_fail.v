module issue1479_assoc_wildcard_foreach_fail;
  int values[*];
  int visits = 0;
  initial begin
    values[3] = 30;
    values[-1] = 10;
    foreach (values[key]) visits++;
  end
endmodule
