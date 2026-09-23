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
    values.pop_front();
    values.pop_back();
    values.push_front(1);
    values.push_back(2);
    values.insert(0, 3);
    item.values.pop_front();
    item.values.push_back(4);
  end
endmodule
