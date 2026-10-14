class constructor_default_base;
  string name;
  local int m_id;

  function new(string name, output int id);
    this.name = name;
    id = m_id++;
  endfunction
endclass

class constructor_default_derived extends constructor_default_base;
  function new(default);
  endfunction
endclass

class constructor_default_implicit extends constructor_default_base(default);
endclass

class constructor_default_explicit_extends extends constructor_default_base(default);
  function new(default);
  endfunction
endclass

class constructor_default_explicit extends constructor_default_base;
  bit enabled;

  function new(default, bit enabled);
    super.new(default);
    this.enabled = enabled;
  endfunction
endclass

class constructor_default_value_base;
  int value;

  function new(input int value = 5);
    this.value = value;
  endfunction
endclass

class constructor_default_value_derived extends constructor_default_value_base;
  function new(default);
  endfunction
endclass

class constructor_default_parameter_base #(int WIDTH = 8);
  logic [WIDTH-1:0] value;

  function new(logic [WIDTH-1:0] value);
    this.value = value;
  endfunction
endclass

class constructor_default_parameter_derived extends constructor_default_parameter_base#(12);
  function new(default);
  endfunction
endclass

package constructor_default_pkg;
  class base;
    int value;
    function new(int value = 7);
      this.value = value;
    endfunction
  endclass
endpackage

class constructor_default_pkg_derived extends constructor_default_pkg::base(default);
endclass

module test;
  int id;
  constructor_default_derived obj;
  constructor_default_implicit implicit_obj;
  constructor_default_explicit_extends explicit_extends_obj;
  constructor_default_explicit explicit_obj;
  constructor_default_value_derived value_obj;
  constructor_default_parameter_derived parameter_obj;
  constructor_default_pkg_derived package_obj;

  initial begin
    id = -1;
    obj = new(.id(id), .name("base"));
    if (obj.name != "base" || id != 0)
      $fatal(1, "constructor defaults failed: name=%s id=%0d", obj.name, id);

    id = -1;
    implicit_obj = new(.id(id), .name("implicit"));
    if (implicit_obj.name != "implicit" || id != 0)
      $fatal(1, "extends default implicit constructor failed: name=%s id=%0d",
             implicit_obj.name, id);

    id = -1;
    explicit_extends_obj = new(.id(id), .name("explicit extends"));
    if (explicit_extends_obj.name != "explicit extends" || id != 0)
      $fatal(1, "extends default explicit constructor failed: name=%s id=%0d",
             explicit_extends_obj.name, id);

    id = -1;
    explicit_obj = new("explicit", id, 1'b1);
    if (explicit_obj.name != "explicit" || id != 0 || !explicit_obj.enabled)
      $fatal(1, "explicit super.new(default) failed: name=%s id=%0d enabled=%0b",
             explicit_obj.name, id, explicit_obj.enabled);

    value_obj = new();
    if (value_obj.value != 5)
      $fatal(1, "inherited default value failed: %0d", value_obj.value);

    parameter_obj = new(12'habc);
    if (parameter_obj.value !== 12'habc)
      $fatal(1, "specialized constructor type failed: %h", parameter_obj.value);

    package_obj = new();
    if (package_obj.value != 7)
      $fatal(1, "package-qualified constructor default failed: %0d", package_obj.value);

    $display("PASSED");
  end
endmodule
