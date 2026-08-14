module test;
  interface class root_if #(type T = int);
    pure virtual function T value();
  endclass

  interface class left_if extends root_if#(int);
    pure virtual function string left_name();
  endclass

  interface class right_if extends root_if#(int);
    pure virtual task add(input int amount);
  endclass

  interface class other_if;
    pure virtual function int marker();
  endclass

  class base;
    function int base_value();
      return 9;
    endfunction
  endclass

  class implementation extends base implements left_if, right_if;
    int current;

    function new(int initial_value);
      current = initial_value;
    endfunction

    virtual function int value();
      return current;
    endfunction

    virtual function string left_name();
      return "left";
    endfunction

    virtual task add(input int amount);
      current += amount;
    endtask
  endclass

  class derived_implementation extends implementation;
    function new(int initial_value);
      super.new(initial_value);
    endfunction

    function int value();
      return current + 100;
    endfunction
  endclass

  class other_implementation implements other_if;
    virtual function int marker();
      return 77;
    endfunction
  endclass

  class byte_implementation implements root_if#(byte);
    byte current;

    function new(byte initial_value);
      current = initial_value;
    endfunction

    virtual function byte value();
      return current;
    endfunction
  endclass

  interface class inherited_if;
    pure virtual function int inherited_value();
  endclass

  class inherited_base;
    virtual function int inherited_value();
      return 31;
    endfunction
  endclass

  class inherited_implementation extends inherited_base
      implements inherited_if;
  endclass

  implementation object;
  derived_implementation derived_object;
  other_implementation other_object;
  byte_implementation byte_object;
  inherited_implementation inherited_object;
  root_if#(int) root_view;
  left_if left_view;
  right_if right_view;
  other_if other_view;
  root_if#(byte) byte_view;
  inherited_if inherited_view;

  initial begin
    object = new(12);
    derived_object = new(23);
    other_object = new;
    byte_object = new(8'h5a);
    inherited_object = new;
    root_view = object;
    left_view = object;
    right_view = object;
    other_view = other_object;
    byte_view = byte_object;
    inherited_view = inherited_object;

    if (root_view.value() != 12)
      $fatal(1, "root interface dispatch failed");
    if (left_view.left_name() != "left")
      $fatal(1, "left interface dispatch failed");
    right_view.add(5);
    if (left_view.value() != 17 || object.base_value() != 9)
      $fatal(1, "transitive interface/base dispatch failed");

    if (!$cast(right_view, left_view))
      $fatal(1, "cast between implemented interfaces failed");
    if (right_view.value() != 17)
      $fatal(1, "successful interface cast changed the object");

    if ($cast(other_view, left_view))
      $fatal(1, "cast to unrelated interface unexpectedly succeeded");
    if (other_view.marker() != 77)
      $fatal(1, "failed interface cast changed its destination");
    if ($cast(byte_view, root_view))
      $fatal(1, "cast between interface specializations unexpectedly succeeded");
    if (byte_view.value() != 8'h5a)
      $fatal(1, "failed specialization cast changed its destination");
    if (inherited_view.inherited_value() != 31)
      $fatal(1, "inherited concrete implementation was not dispatched");

    root_view = derived_object;
    if (root_view.value() != 123)
      $fatal(1, "implicit virtual interface implementation did not dispatch");

    $display("PASSED");
  end
endmodule
