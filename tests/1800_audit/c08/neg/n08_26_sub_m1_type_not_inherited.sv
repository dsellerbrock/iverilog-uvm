interface class IntfC;
  typedef enum {ONE, TWO, THREE} t1_t;
  pure virtual function t1_t funcC();
endclass

class Bad implements IntfC;
  t1_t t1_i;
  virtual function IntfC::t1_t funcC();
    return IntfC::ONE;
  endfunction
endclass

module n08_26_sub_m1_type_not_inherited;
  Bad obj;
  initial obj = new;
endmodule
