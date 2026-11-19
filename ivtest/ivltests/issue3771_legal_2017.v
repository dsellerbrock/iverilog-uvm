package provider_pkg;
  class Base;
    static int state = 11;
    static task set(int value);
      state = value;
    endtask
    static function int get();
      return state;
    endfunction
    task put(int value);
      state = value;
    endtask
    function int read();
      return state + 100;
    endfunction
  endclass
  typedef Base ImportedAlias;
endpackage

class UnitClass;
  static int state = 29;
  static function int read();
    return -1;
  endfunction
  static task set(int value);
    state = value;
  endtask
  static function int get();
    return state;
  endfunction
endclass
typedef UnitClass ImportedAlias;

package consumers;
  import provider_pkg::ImportedAlias;

  class Adapter #(type T = provider_pkg::Base);
    typedef T LocalAlias;
    static function int get();
      return T::get() + LocalAlias::state;
    endfunction
    static task set(int value);
      T::set(value);
      LocalAlias::state = value + 1;
    endtask
    static function int get_through_object();
      T object;
      object = new;
      return object.get();
    endfunction
  endclass

  class LocalHolder;
    provider_pkg::Base UnitClass;
    function new();
      UnitClass = new;
    endfunction
    function int read();
      return UnitClass.read();
    endfunction
    task set(int value);
      UnitClass.put(value);
    endtask
  endclass

  function int imported_get();
    return ImportedAlias::get();
  endfunction
endpackage

module top;
  typedef consumers::Adapter#(UnitClass) Specialized;
  consumers::LocalHolder holder;
  initial begin
    typedef UnitClass CallerType;
    consumers::Adapter#(CallerType)::set(38);
    if (Specialized::get() !== 78 || Specialized::get_through_object() !== 39)
      $fatal(1, "wrong specialized binding");
    if (consumers::imported_get() !== 11)
      $fatal(1, "wrong imported binding");
    holder = new;
    holder.set(18);
    if (holder.read() !== 118 || consumers::imported_get() !== 18
        || UnitClass::state !== 39)
      $fatal(1, "wrong receiver binding");
    $display("PASSED");
  end
endmodule
