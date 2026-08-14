module test;
  interface class concrete_method_if;
    function int value();
      return 1;
    endfunction
  endclass

  interface class property_if;
    int value;
  endclass

  interface class constraint_if;
    rand int value;
    constraint positive { value > 0; }
  endclass

  interface class static_method_if;
    static function int value();
      return 1;
    endfunction
  endclass

  interface class event_if;
    event changed;
  endclass
endmodule
