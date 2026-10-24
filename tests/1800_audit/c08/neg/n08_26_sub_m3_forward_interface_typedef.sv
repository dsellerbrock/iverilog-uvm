typedef interface class IntfD;

class ClassD implements IntfD#(bit);
  virtual function bit [1:0] funcD();
    return 0;
  endfunction
endclass

interface class IntfD #(type T1 = logic);
  typedef T1[1:0] T2;
  pure virtual function T2 funcD();
endclass

module n08_26_sub_m3_forward_interface_typedef;
  ClassD obj;
  initial obj = new;
endmodule
