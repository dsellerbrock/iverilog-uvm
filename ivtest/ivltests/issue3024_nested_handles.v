class issue3024_item;
  int value;
endclass

module issue3024_nested_handles;
  issue3024_item items[2][], a, b, result;
  int outer, inner;
  initial begin
    items[0] = new[2];
    items[1] = new[2];
    a = new; a.value = 9;
    b = new; b.value = 17;
    items[0][0] = a;
    items[1][1] = b;
    outer = 0; inner = 0;
    result = items[outer][inner];
    if (result != a || result == null) $fatal(1, "first handle lost");
    if (result.value != 9) $fatal(1, "first object changed");
    outer = 1; inner = 1;
    result = items[outer][inner];
    if (result != b || result == null) $fatal(1, "second handle lost");
    if (result.value != 17) $fatal(1, "second object changed");
    result = items[1][0];
    if (result != null) $fatal(1, "unassigned handle is not null");
    items[0][0] = b;
    result = items[0][0];
    if (result != b) $fatal(1, "replacement handle lost");
    $display("PASS");
  end
endmodule
