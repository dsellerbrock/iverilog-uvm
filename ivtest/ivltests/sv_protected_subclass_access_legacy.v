class Base;
  protected int value = 0;
endclass
class Derived extends Base;
  protected function int secret();
    return value;
  endfunction
  function int read_value();
    return secret();
  endfunction
  function void write_value(int v);
    value = v;
  endfunction
endclass
module sv_protected_subclass_access;
  Derived d;
  initial begin
    d = new;
    d.write_value(7);
    $display("subclass access=%0d", d.read_value());
  end
endmodule
