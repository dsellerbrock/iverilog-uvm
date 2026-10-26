class Base;
  local int value = 1;
  function int base_read(); return value; endfunction
endclass

class Derived extends Base;
  function int get(); return value; endfunction
endclass

module issue1212_local_subclass_access;
  Derived d;
  initial begin d = new; $display("%0d", d.get()); end
endmodule
