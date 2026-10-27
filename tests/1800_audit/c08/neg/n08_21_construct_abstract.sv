// IEEE 1800-2017/2023 §8.21: an abstract class shall not be constructed directly.
virtual class AbstractBase;
  pure virtual function integer send();
endclass

module n08_21_construct_abstract;
  AbstractBase obj;
  initial obj = new;
endmodule
