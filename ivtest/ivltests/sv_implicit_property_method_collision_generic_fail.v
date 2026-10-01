class generic_collision #(parameter int Width = 2);
  static function int value; return Width; endfunction
endclass
class generic_helper;
  function int value; return 9; endfunction
endclass
class generic_owner;
  generic_helper generic_collision;
  function void run;
    generic_collision::value();
  endfunction
endclass
module sv_implicit_property_method_collision_generic_fail;
  initial begin generic_owner owner; owner = new; owner.run(); end
endmodule
