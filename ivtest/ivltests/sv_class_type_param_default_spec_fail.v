// IEEE 1800-2017/2023 8.25 -- residual half of
// sv_class_type_param_scoped_call_template_seed.
//
// "The default specialization of a parameterized class is the specialization
// of the parameterized class with an empty parameter override list." C#() is
// a real specialization, not the generic body, even though its parameter
// binds to a NON-class type. `int' has no tag(), so this must stay a loud
// error -- the template-seed rule must not swallow it. slang rejects it too.
//
// This is the exact hole the first draft of the fix opened: keying only on
// "the parameter binds to no class" silently accepted this file.
module main;
  class common #(type Treg = int);
    static function int poke(); return Treg::tag(); endfunction
  endclass
  initial $display("%0d", common#()::poke());
endmodule
