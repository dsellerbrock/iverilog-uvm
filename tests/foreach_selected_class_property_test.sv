// IEEE 1800-2017 12.7.3: foreach over the remaining dimensions of a
// selected fixed-array class property.
module foreach_selected_class_property_test;
  class holder;
    bit [7:0][31:0] key[2];
  endclass

  holder h;
  int count;
  int sum;
  initial begin
    h = new;
    foreach (h.key[0][i]) h.key[0][i] = i + 1;
    foreach (h.key[0][i]) begin
      count++;
      sum += h.key[0][i];
    end
    if (count == 8 && sum == 36)
      $display("PASS: foreach selected class property");
    else
      $display("FAIL: foreach selected class property count=%0d sum=%0d",
               count, sum);
    $finish;
  end
endmodule
