interface class PutImp #(type T = int);
  pure virtual function void put(T a);
endclass

class MissingPut implements PutImp#(int);
endclass

module n08_26_missing_implementation;
  MissingPut obj;
  initial obj = new;
endmodule
