module top;
  class Main;
    int value = 5;
    extern function new();
    extern function int external_value();

    static function int static_value();
      return 7;
    endfunction

    task bump();
      begin : method_block
        int local_value;
        local_value = value + 1;
        value = local_value;
      end
    endtask

    class Nested;
      function int nested_value();
        return 3;
      endfunction
    endclass
  endclass

  function Main::new();
    value += 2;
  endfunction

  function int Main::external_value();
    return value;
  endfunction

  class WithInitializer extends Main;
    int initialized = 11;
  endclass

  virtual class Prototypes;
    pure virtual function int required_value();
    pure virtual task required_task();
  endclass

  initial begin
    Main::Nested nested;
    Main explicit_ctor;
    WithInitializer implicit_ctor;
    nested = new;
    explicit_ctor = new;
    implicit_ctor = new;
    explicit_ctor.bump();
    if (nested.nested_value() != 3 || Main::static_value() != 7 ||
        explicit_ctor.external_value() != 8 || implicit_ctor.external_value() != 7 ||
        implicit_ctor.initialized != 11)
      $fatal(1, "unexpected method or constructor behavior");
  end
endmodule
