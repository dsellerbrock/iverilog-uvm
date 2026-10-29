module top;
  int values[*];
  int visits=0;
  initial begin
    values[3]=30; values[-1]=10;
    foreach (values[key]) visits++;
    $display("foreach accepted visits=%0d",visits);
  end
endmodule
