// IEEE 1800-2017/2023 §§8.20–8.22: virtual overrides, abstract classes,
// callable empty method bodies, and dynamic lookup through superclass handles.
class V1Base;
  virtual function string f(); return "A"; endfunction
endclass

class V1Mid extends V1Base;
  function string f(); return "B"; endfunction
endclass

class V1Leaf extends V1Mid;
  function string f(); return "C"; endfunction
endclass

class V2Base;
  function string g(); return "A2"; endfunction
endclass

class V2Mid extends V2Base;
  virtual function string g(); return "B2"; endfunction
endclass

class V2Leaf extends V2Mid;
  function string g(); return "C2"; endfunction
endclass

virtual class PacketBase;
  int k;
  function new(); k = 5; endfunction
  pure virtual function integer send();
endclass

class EtherPacket extends PacketBase;
  virtual function integer send(); return k; endfunction
endclass

virtual class EmptyBodyBase;
  virtual function integer send(); endfunction
endclass

class EmptyBodyDerived extends EmptyBodyBase;
endclass

virtual class PolyPacket;
  pure virtual function string send();
endclass

class Ether extends PolyPacket;
  virtual function string send(); return "Ether"; endfunction
endclass

class Token extends PolyPacket;
  virtual function string send(); return "Token"; endfunction
endclass

class GPS extends Ether;
  virtual function string send(); return "GPS"; endfunction
endclass

module p08_20_22;
  V1Base v1a;
  V1Mid v1b;
  V1Leaf v1obj;
  V2Base v2a;
  V2Mid v2b;
  V2Leaf v2obj;
  PacketBase bp;
  EmptyBodyBase eb;
  PolyPacket packets[3];
  EtherPacket ep;
  EmptyBodyDerived empty_obj;
  Ether ether_obj;
  Token token_obj;
  GPS gps_obj;

  initial begin
    v1obj = new;
    v1a = v1obj;
    v1b = v1obj;
    $display("V1 %s %s", v1a.f(), v1b.f());

    v2obj = new;
    v2a = v2obj;
    v2b = v2obj;
    $display("V2 %s %s", v2a.g(), v2b.g());

    ep = new;
    bp = ep;
    $display("AB1 %0d", bp.send());

    empty_obj = new;
    eb = empty_obj;
    $display("AB2 %0d", eb.send());

    ether_obj = new;
    token_obj = new;
    gps_obj = new;
    packets[0] = ether_obj;
    packets[1] = token_obj;
    packets[2] = gps_obj;
    $display("POLY %s %s %s", packets[0].send(), packets[1].send(), packets[2].send());
  end
endmodule
