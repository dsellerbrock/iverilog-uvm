module n13_08_new_virtual_class;
  virtual class C#(parameter W = 4);
    static function int f(); return W; endfunction
  endclass

  C#(4) c;
  initial c = new;
endmodule
