interface class PutImp #(type PUT_T = int);
  pure virtual function void put(PUT_T a);
endclass

module n08_26_sub_m4_new_interface_handle;
  PutImp#(int) put_ref;
  initial put_ref = new();
endmodule
