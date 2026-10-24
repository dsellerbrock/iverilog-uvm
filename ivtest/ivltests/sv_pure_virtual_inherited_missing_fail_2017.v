// IEEE 1800-2017 8.21: concrete subclasses must implement inherited pure
// virtual methods before they can be constructed.
virtual class sv_pure_virtual_inherited_base;
  pure virtual function integer send();
endclass

class sv_pure_virtual_inherited_missing extends sv_pure_virtual_inherited_base;
endclass

module sv_pure_virtual_inherited_missing_fail_2017;
  initial begin
    sv_pure_virtual_inherited_missing item;
    item = new;
    $display("MISSING %0d", item.send());
  end
endmodule
