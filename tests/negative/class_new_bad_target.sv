// IEEE 1800-2017 8.7/8.21: `new` produces a class handle -- assigning it
// to a non-class variable is a type error, and an abstract (virtual)
// class can never be instantiated. Both were silently accepted through
// compile-progress stubs (vendored ivtest sv_class_new_fail1,
// sv_class_virt_new_fail).
module class_new_bad_target;
  virtual class VC;
  endclass
  VC vc;
  int i;
  initial begin
    i = new;     // error: class new to non-class target
    vc = new;    // error: instantiating a virtual class
  end
endmodule
