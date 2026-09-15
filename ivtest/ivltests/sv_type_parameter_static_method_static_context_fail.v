class receiver_base;
  function void put(int value); endfunction
endclass
class receiver_derived extends receiver_base;
  static function void run(); receiver_base::put(1); endfunction
endclass
module test;
  initial receiver_derived::run();
endmodule
