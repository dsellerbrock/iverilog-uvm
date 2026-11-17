// IEEE 1800-2017/2023 8.20: "Virtual method overrides in subclasses shall
// have matching argument types, identical argument names, identical
// qualifiers, and identical directions to the prototype. ... the presence
// of a default shall match", and the return type shall be a matching type
// or a derived class type of the prototype's.
class R; endclass
class Base;
  virtual function int f_name(int a); return a; endfunction
  virtual function int f_dir(input int a); return a; endfunction
  virtual function int f_dflt(int a = 1); return a; endfunction
  virtual function int f_type(int a); return a; endfunction
  virtual function R f_ret(); return null; endfunction
endclass
class Derived extends Base;
  function int f_name(int b); return b; endfunction
  function int f_dir(output int a); a = 0; return 0; endfunction
  function int f_dflt(int a); return a; endfunction
  function int f_type(byte a); return a; endfunction
  function int f_ret(); return 0; endfunction
endclass
module top; endmodule
