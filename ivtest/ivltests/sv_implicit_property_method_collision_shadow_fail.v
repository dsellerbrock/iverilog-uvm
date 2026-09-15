class shadow_collision #(parameter int Width = 2); endclass
class shadow_helper; function void sample; endfunction endclass
class shadow_owner;
  shadow_helper shadow_collision;
  function void run;
    int shadow_collision;
    shadow_collision.sample();
  endfunction
endclass
module sv_implicit_property_method_collision_shadow_fail;
  initial begin shadow_owner owner; owner = new; owner.run(); end
endmodule
