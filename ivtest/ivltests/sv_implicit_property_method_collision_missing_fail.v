class missing_collision #(parameter int Width = 2); endclass
class missing_helper; endclass
class missing_owner;
  missing_helper missing_collision;
  function void run;
    missing_collision.no_such_method();
  endfunction
endclass
module sv_implicit_property_method_collision_missing_fail;
  initial begin missing_owner owner; owner = new; owner.run(); end
endmodule
