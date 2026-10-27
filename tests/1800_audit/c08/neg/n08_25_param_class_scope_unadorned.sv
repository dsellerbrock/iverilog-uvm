// IEEE 1800-2017/2023 §8.25.1: outside class scope, C:: is illegal here.
class C #(int p = 1);
endclass

module n08_25_param_class_scope_unadorned;
  int x = C::p;
endmodule
