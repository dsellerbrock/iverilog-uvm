// The non-overridable built-ins are rejected for tasks and extern methods as
// well as ordinary functions. A parameterized class is diagnosed once at its
// declaration, not once per exact/default-equivalent specialization.
class extern_bad;
  extern function int randomize();
  extern task rand_mode();
endclass

function int extern_bad::randomize();
  return 1;
endfunction

task extern_bad::rand_mode();
endtask

class clean_base;
endclass

class derived_bad extends clean_base;
  task constraint_mode();
  endtask
endclass

class generic_bad #(int TAG = 0);
  task randomize();
  endtask
endclass

module test;
  generic_bad#() default_obj;
  generic_bad#(0) explicit_default_obj;
  generic_bad#(1) one_obj;
  generic_bad#(2) two_obj;
  derived_bad derived_obj;
  extern_bad extern_obj;
endmodule
