module test;
  interface class required_if;
    pure virtual function int required_value();
  endclass

  class incomplete implements required_if;
  endclass

  incomplete object;
  initial object = new;
endmodule
