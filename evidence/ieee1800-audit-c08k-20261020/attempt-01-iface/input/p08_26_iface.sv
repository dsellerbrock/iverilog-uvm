interface class PutImp #(type PUT_T = logic);
  pure virtual function void put(PUT_T a);
endclass

interface class GetImp #(type GET_T = logic);
  pure virtual function GET_T get();
endclass

class Fifo #(type T = logic, int DEPTH = 1) implements PutImp#(T), GetImp#(T);
  T myFifo[$:DEPTH-1];
  virtual function void put(T a);
    myFifo.push_back(a);
  endfunction
  virtual function T get();
    get = myFifo.pop_front();
  endfunction
endclass

class Stack #(type T = logic, int DEPTH = 1) implements PutImp#(T), GetImp#(T);
  T myFifo[$:DEPTH-1];
  virtual function void put(T a);
    myFifo.push_front(a);
  endfunction
  virtual function T get();
    get = myFifo.pop_front();
  endfunction
endclass

class C2 extends Fifo#(int, 4);
endclass

module p08_26_iface;
  PutImp#(int) p;
  GetImp#(int) g;
  Fifo#(int, 4) f;
  Stack#(int, 4) s;
  C2 c;

  initial begin
    f = new;
    s = new;
    c = new;

    p = f;
    g = f;
    p.put(1);
    p.put(2);
    $display("FIFO %0d %0d", g.get(), g.get());

    p = s;
    g = s;
    p.put(1);
    p.put(2);
    $display("STACK %0d %0d", g.get(), g.get());

    p = c;
    p.put(7);
    g = c;
    $display("INH %0d", g.get());
  end
endmodule
