// IEEE 1800-2017/2023 §8.21: a pure virtual method has no method body.
virtual class AbstractBase;
  pure virtual function integer send();
  endfunction
endclass

module n08_21_pure_with_body;
endmodule
