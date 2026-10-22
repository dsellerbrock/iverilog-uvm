interface class PutImp #(type PUT_T = logic);
  pure virtual function void put(PUT_T a);
endclass

class Fifo #(type T = PutImp) implements T;
  virtual function void put(logic a);
  endfunction
endclass

module n08_26_sub_m2_implements_type_parameter;
  Fifo#() obj;
  initial obj = new;
endmodule
