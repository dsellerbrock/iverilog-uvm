// G32: method-chain on class-handle function returns (builder pattern)
class Builder;
  int val;
  function Builder set_val(int v);
    val = v;
    return this;
  endfunction
  function Builder add(int v);
    val += v;
    return this;
  endfunction
endclass

module p84_func_return_class;
  Builder b;
  Builder result;
  initial begin
    b = new();
    result = b.set_val(10).add(5);
    if (result.val == 15)
      $display("PASS");
    else
      $display("FAIL: got %0d", result.val);
  end
endmodule
