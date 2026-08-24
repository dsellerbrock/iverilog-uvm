// The implicit pre_randomize() and post_randomize() prototypes have no
// arguments. Check ordinary, super, and receiver-expression call paths.
class empty_hook_base;
endclass

class implicit_super_child extends empty_hook_base;
  function void bad_super_call();
    super.pre_randomize(1);
  endfunction
endclass

module test;
  empty_hook_base object;

  function empty_hook_base make_object();
    return object;
  endfunction

  initial begin
    object = new;
    object.post_randomize(1);
    make_object().pre_randomize(1);
  end
endmodule
