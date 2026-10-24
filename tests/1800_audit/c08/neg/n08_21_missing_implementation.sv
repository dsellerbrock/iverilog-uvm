// IEEE 1800-2017/2023 §8.21: a non-abstract subclass must implement pure methods.
virtual class AbstractBase;
  pure virtual function integer send();
endclass

class MissingImplementation extends AbstractBase;
endclass

module n08_21_missing_implementation;
  MissingImplementation obj;
  initial begin
    obj = new;
    $display("MISSING %0d", obj.send());
  end
endmodule
