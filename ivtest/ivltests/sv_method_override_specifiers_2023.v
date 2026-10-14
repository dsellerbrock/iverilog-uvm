class method_override_base;
  virtual function int dynamic_value(input int value);
    return value;
  endfunction

  function int hidden_value(input int value);
    return value;
  endfunction

  virtual task announce();
    $display("base task");
  endtask

  virtual function int sealed_value(input int value);
    return value;
  endfunction
endclass

class method_override_derived extends method_override_base;
  function :extends int dynamic_value(input int value);
    return value + 1;
  endfunction

  function :initial int hidden_value(input int value);
    return value + 2;
  endfunction

  function :final int final_value(input int value);
    return value + 3;
  endfunction

  function :final :initial int final_initial_value(input int value);
    return value + 6;
  endfunction

  function :final :extends int sealed_value(input int value);
    return value + 4;
  endfunction

  task :extends announce();
    $display("derived task");
  endtask
endclass

class method_override_extern_base;
  virtual function int external_value(input int value);
    return value;
  endfunction
endclass

class method_override_extern_derived extends method_override_extern_base;
  extern function :extends int external_value(input int value);
endclass

function int method_override_extern_derived::external_value(input int value);
  return value + 5;
endfunction

interface class method_override_api;
  pure virtual function int value();
  pure virtual function :initial int initial_value();
endclass

interface class method_override_extended_api extends method_override_api;
  pure virtual function :extends int value();
endclass

class method_override_api_impl implements method_override_extended_api;
  virtual function int value();
    return 7;
  endfunction

  virtual function int initial_value();
    return 8;
  endfunction
endclass

module test;
  method_override_base base;
  method_override_derived derived;
  method_override_extern_base extern_base;
  method_override_extern_derived extern_derived;
  method_override_api api;
  method_override_api_impl api_impl;

  initial begin
    derived = new;
    base = derived;
    if (base.dynamic_value(1) != 2)
      $fatal(1, "extends did not imply virtual dispatch");
    if (derived.hidden_value(1) != 3)
      $fatal(1, "initial method failed");
    if (derived.final_value(1) != 4)
      $fatal(1, "final method failed");
    if (derived.final_initial_value(1) != 7)
      $fatal(1, "final+initial method failed");
    if (base.sealed_value(1) != 5)
      $fatal(1, "final+extends did not preserve virtual dispatch");
    base.announce();
    extern_derived = new;
    extern_base = extern_derived;
    if (extern_base.external_value(1) != 6)
      $fatal(1, "extern :extends prototype did not preserve dispatch");
    api_impl = new;
    api = api_impl;
    if (api.value() != 7)
      $fatal(1, "interface-class :extends prototype failed");
    if (api.initial_value() != 8)
      $fatal(1, "interface-class :initial prototype failed");
    $display("PASSED");
  end
endmodule
