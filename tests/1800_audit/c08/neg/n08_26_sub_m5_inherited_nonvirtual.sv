interface class IntfClass2;
  pure virtual function void f();
endclass

class BaseClass2;
  function void f();
  endfunction
endclass

class ExtClass2 extends BaseClass2 implements IntfClass2;
endclass

module n08_26_sub_m5_inherited_nonvirtual;
  ExtClass2 obj;
  initial obj = new;
endmodule
