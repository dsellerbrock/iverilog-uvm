// A nested static-object path must diagnose an absent instance property; it
// must not degrade to an export-time assertion or a zero-valued fallback.
module sv_class_static_nested_property_missing_fail;
  class payload;
    int value;
  endclass

  class wrapper #(type IMP = int);
    static payload item;
  endclass

  initial begin
    int value;
    value = wrapper#(int)::item.missing;
  end
endmodule
