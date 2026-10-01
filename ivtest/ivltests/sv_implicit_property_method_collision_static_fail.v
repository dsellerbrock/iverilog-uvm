class static_collision #(parameter int Width = 2); endclass
class static_helper; function void sample; endfunction endclass
class static_owner;
  static_helper static_collision;
  static function void run;
    static_collision.sample();
  endfunction
endclass
module sv_implicit_property_method_collision_static_fail;
  initial static_owner::run();
endmodule
