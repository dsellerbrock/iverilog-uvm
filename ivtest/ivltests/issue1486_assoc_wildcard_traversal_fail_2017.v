module top;
  int values[*];
  int index, status;

  initial begin
    status = values.first(index);
    status = values.last(index);
    status = values.next(index);
    status = values.prev(index);
  end
endmodule
