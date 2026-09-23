class holder;
  int values[int];
endclass

module test;
  holder item;
  int values[int];
  int result;

  initial begin
    item = new;
    item.values[1] = 7;
    values[1] = 7;
    result = item.values.pop_front;
    result = item.values.pop_back();
    result = values.pop_front;
    result = values.pop_back();
  end
endmodule
