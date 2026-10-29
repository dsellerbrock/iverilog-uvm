class expected_key; endclass
class derived_key extends expected_key; endclass
module top;
  int values[expected_key];
  expected_key base_key;
  derived_key child_key;
  initial begin
    base_key = new;
    child_key = new;
    values[base_key] = 1;
    values[child_key] = 2;
    values[null] = 3;
    $display("entries=%0d", values.num());
  end
endmodule
