module test;
  interface class required_if;
    pure virtual function int value();
  endclass

  class nonvirtual_implementation implements required_if;
    function int value();
      return 1;
    endfunction
  endclass
endmodule
