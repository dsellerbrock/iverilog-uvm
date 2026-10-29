class expected_key; endclass
class unrelated_key; endclass
module top;
  int values[expected_key];
  unrelated_key key;
  initial begin
    key = new;
    values[key] = 1;
  end
endmodule
