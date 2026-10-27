interface class IntfClass;
  pure virtual function bit funcBase();
  pure virtual function bit funcExt();
endclass

class BaseClass;
  virtual function bit funcBase();
    return 1;
  endfunction
endclass

class ExtClass extends BaseClass implements IntfClass;
  virtual function bit funcExt();
    return 0;
  endfunction
endclass

interface class IntfClass2;
  pure virtual function void f();
endclass

class BaseClass2;
  function void f();
    $display("Base");
  endfunction
endclass

class ExtClass2 extends BaseClass2 implements IntfClass2;
  virtual function void f();
    $display("Ext");
  endfunction
endclass

interface class IntfA #(type T1 = logic);
  typedef T1[1:0] T2;
  pure virtual function T2 funcA();
endclass : IntfA

interface class IntfB #(type T = bit) extends IntfA#(T);
  pure virtual function T2 funcB();
endclass : IntfB

class ClassAB implements IntfB#(bit);
  virtual function bit [1:0] funcA();
    return 1;
  endfunction
  virtual function bit [1:0] funcB();
    return 2;
  endfunction
endclass

interface class IntfC;
  typedef enum {ONE, TWO, THREE} t1_t;
  pure virtual function t1_t funcC();
endclass : IntfC

class ClassC implements IntfC;
  virtual function IntfC::t1_t funcC();
    return IntfC::ONE;
  endfunction : funcC
endclass

interface class PutImp #(type PUT_T = logic);
  pure virtual function void put(PUT_T a);
endclass

interface class GetImp #(type GET_T = logic);
  pure virtual function GET_T get();
endclass

class Fifo #(type T = int) implements PutImp#(T), GetImp#(T);
  virtual function void put(T a);
  endfunction
  virtual function T get();
    return 0;
  endfunction
endclass

class OnlyPut implements PutImp#(int);
  virtual function void put(int a);
  endfunction
endclass

interface class IntfBase1;
  pure virtual function bit funcBase();
endclass

interface class IntfBase2;
  pure virtual function bit funcBase();
endclass

class Both implements IntfBase1, IntfBase2;
  virtual function bit funcBase();
    return 1;
  endfunction
endclass

module p08_26_sub;
  IntfClass i1;
  ExtClass e1;
  IntfClass2 i2;
  ExtClass2 e2;
  ClassAB ab;
  ClassC c;
  PutImp#(int) put_ref;
  GetImp#(int) get_ref;
  Fifo#(int) fifo_obj, fifo2;
  OnlyPut op;
  int rc1, rc2, rc3;
  Both both;
  IntfBase1 h1;
  IntfBase2 h2;

  initial begin
    e1 = new;
    i1 = e1;
    $display("K1 %0d %0d", i1.funcBase(), i1.funcExt());

    e2 = new;
    i2 = e2;
    i2.f();

    ab = new;
    c = new;
    $display("K3A %0d %0d", ab.funcA(), ab.funcB());
    $display("K3 %0d", c.funcC() == IntfC::ONE);

    fifo_obj = new;
    put_ref = fifo_obj;
    rc1 = $cast(get_ref, put_ref);
    rc2 = $cast(fifo2, put_ref);
    op = new;
    put_ref = op;
    rc3 = $cast(get_ref, put_ref);
    $display("K4 %0d %0d %0d", rc1, rc2, rc3);

    both = new;
    h1 = both;
    h2 = both;
    $display("K5 %0d %0d", h1.funcBase(), h2.funcBase());
  end
endmodule
