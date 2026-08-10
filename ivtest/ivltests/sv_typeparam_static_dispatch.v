// A type parameter is already a type, so T::method() stays legal. Explicit
// empty and non-empty class specializations must both bind T concretely.
module sv_typeparam_static_dispatch;
  class impl;
    static int slot = 32;

    static function int value;
      return 31;
    endfunction

    static task fetch(output int result);
      result = 33;
    endtask
  endclass

  class impl_alt;
    static int slot = 48;

    static function int value;
      return 47;
    endfunction

    static task fetch(output int result);
      result = 49;
    endtask
  endclass

  class outer #(type T = impl);
    static function int call;
      return T::value();
    endfunction

    static function int read_property;
      return T::slot;
    endfunction

    static task call_task(output int result);
      T::fetch(result);
    endtask
  endclass

  class self #(int V = 1);
    static int slot = V;

    static function int value;
      return V;
    endfunction

    static function int call_self;
      return self::value() + self::slot;
    endfunction

    static task leaf_task(output int result);
      result = V;
    endtask

    static task fetch_self(output int result);
      self::leaf_task(result);
    endtask
  endclass

  initial begin
    int default_task_value;
    int alternate_task_value;
    int self_task_value;

    outer#()::call_task(default_task_value);
    outer#(impl_alt)::call_task(alternate_task_value);
    self#(7)::fetch_self(self_task_value);

    if (outer#()::call() !== 31
        || outer#()::read_property() !== 32
        || default_task_value !== 33
        || outer#(impl_alt)::call() !== 47
        || outer#(impl_alt)::read_property() !== 48
        || alternate_task_value !== 49
        || self#(7)::call_self() !== 14
        || self_task_value !== 7)
      $fatal(1, "type-parameter static dispatch failed");
    $display("PASSED");
  end
endmodule
