package collision_pkg;
  class same_name #(parameter int Width = 3); endclass
endpackage
import collision_pkg::*;
class package_helper;
  int value;
  function void set(input int v); value = v; endfunction
endclass
class package_owner;
  package_helper same_name;
  function void run;
    same_name = new;
    if (same_name != null) same_name.set(9);
  endfunction
endclass
module sv_implicit_property_method_collision_package;
  initial begin
    package_owner owner; owner = new; owner.run();
    if (owner.same_name.value != 9) $fatal(1, "package collision failed");
    $display("PASSED");
  end
endmodule
