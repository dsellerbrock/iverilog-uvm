// A nested instance-property read rooted at a static class handle must retain
// the static signal through the dangling-signal pass and VVP export. Exercise
// both ordinary and explicitly specialized parameterized classes. The handles
// intentionally remain null; the plusarg keeps the reads live in generated
// code without dereferencing them during the regression run.
module sv_class_static_nested_property_lifetime;
  class plain_payload;
    int value;
  endclass

  class plain_wrapper;
    static plain_payload item;
  endclass

  class param_payload;
    int value;
  endclass

  class param_wrapper #(type IMP = int);
    static param_payload item;
  endclass

  initial begin
    int plain_value;
    int parameterized_value;
    if ($test$plusargs("read-null-static-handles")) begin
      plain_value = plain_wrapper::item.value;
      parameterized_value = param_wrapper#(int)::item.value;
      if (plain_value !== parameterized_value)
        $display("nested values differ: %0d %0d",
                 plain_value, parameterized_value);
    end
    $display("PASSED");
  end
endmodule
