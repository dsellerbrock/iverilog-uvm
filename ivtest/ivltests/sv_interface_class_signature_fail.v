module test;
  interface class function_if;
    pure virtual function int operate(input int value);
  endclass

  interface class task_if;
    pure virtual task operate(output int value);
  endclass

  class incompatible implements function_if, task_if;
    virtual function int operate(input int value);
      return value;
    endfunction
  endclass

  interface class method_if;
    pure virtual function int transform(input int value);
  endclass

  class wrong_return implements method_if;
    virtual function shortint transform(input int value);
      return value;
    endfunction
  endclass

  class wrong_direction implements method_if;
    virtual function int transform(output int value);
      value = 1;
      return value;
    endfunction
  endclass

  class wrong_type implements method_if;
    virtual function int transform(input shortint value);
      return value;
    endfunction
  endclass

  class wrong_count implements method_if;
    virtual function int transform(input int value, input int extra);
      return value + extra;
    endfunction
  endclass
endmodule
