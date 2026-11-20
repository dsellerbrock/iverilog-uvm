// IEEE 1800-2017/2023 8.20: "Virtual method overrides in subclasses shall
// have matching argument types"; the return type shall be a matching type or
// a class derived from the prototype's return type. This holds when the
// prototype is in a parameterized base, including one named through a
// forward `typedef class' that is declared later.
typedef class fwd_proxy;
class E; endclass
class G; endclass

class PFwd extends fwd_proxy #(E);
  function void f(int s); endfunction
endclass

virtual class proxy #(type T = int);
  pure virtual function void f(T s);
  pure virtual function T make();
endclass

virtual class fwd_proxy #(type T = int);
  pure virtual function void f(T s);
endclass

class P extends proxy #(E);
  function void f(int s); endfunction
  function G make(); return null; endfunction
endclass

module issue3701_bad;
endmodule
