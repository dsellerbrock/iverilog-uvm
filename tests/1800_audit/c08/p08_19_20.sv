// IEEE 1800-2017/2023 §§8.19–8.20: constants and matching virtual overrides.
class Jumbo_Packet;
  const int max_size = 9 * 1024;
  byte payload[];
  function new(int size);
    payload = new[size > max_size ? max_size : size];
  endfunction
endclass

class BP;
  const int size;
  function new(int s); size = s; endfunction
endclass

class ReturnBase;
  virtual function ReturnBase make(); return null; endfunction
endclass

class ReturnDerived extends ReturnBase;
  function ReturnDerived make(); return this; endfunction
endclass

class DefaultBase;
  virtual function int h(int a = 1); return a; endfunction
endclass

class DefaultDerived extends DefaultBase;
  function int h(int a = 2); return a; endfunction
endclass

module p08_19_20;
  Jumbo_Packet jumbo, small_pkt;
  BP bp3, bp4;
  ReturnBase rb, returned;
  ReturnDerived rd;
  DefaultBase db;
  DefaultDerived dd;

  initial begin
    jumbo = new(10000);
    small_pkt = new(5);
    $display("K1 %0d %0d", jumbo.payload.size(), small_pkt.payload.size());

    bp3 = new(3);
    bp4 = new(4);
    $display("K2 %0d %0d", bp3.size, bp4.size);

    rd = new;
    rb = rd;
    returned = rb.make();
    if (returned == rd) $display("V6 ok"); else $display("V6 fail");

    dd = new;
    db = dd;
    $display("V7 %0d", db.h());
  end
endmodule
