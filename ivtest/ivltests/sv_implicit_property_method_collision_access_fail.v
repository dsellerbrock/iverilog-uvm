class access_collision #(parameter int Width = 2); endclass
class access_helper; function void sample; endfunction endclass
class access_base;
  local access_helper access_collision;
endclass
class access_owner extends access_base;
  function void run;
    access_collision.sample();
  endfunction
endclass
module sv_implicit_property_method_collision_access_fail;
  initial begin access_owner owner; owner = new; owner.run(); end
endmodule
