// These fixed-array locator forms are legal. Keep them loud until the loop
// can iterate subarrays and carry nonintegral element values faithfully.
module multidimensional_fixed;
  int values[1:0][1:0];

  initial
    $display("%p", values.find_last with (item[0] > 0));
endmodule

module nonintegral_fixed;
  string values[1:0];
  string found[$];

  initial
    found = values.find_last with (item == "match");
endmodule

class fixed_holder;
  int values[1:0];
endclass

module fixed_class_property;
  fixed_holder holder;
  int found[$];

  initial begin
    holder = new;
    found = holder.values.find_last with (item > 0);
  end
endmodule
