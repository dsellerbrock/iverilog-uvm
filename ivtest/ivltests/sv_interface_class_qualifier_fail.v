module test;
  interface class protected_if;
    pure virtual protected function int value();
  endclass

  interface class local_if;
    pure virtual local task run();
  endclass

  interface class static_if;
    pure virtual static function int marker();
  endclass
endmodule
