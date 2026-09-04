// IEEE 1800-2017/2023 8.25 -- residual half of
// sv_class_type_param_scoped_call_template_seed.
//
// The template-seed rule suppresses nothing once the type parameter is BOUND.
// Here Treg binds to a real class that genuinely has no tag(), so this is a
// concrete use site and must stay a loud error. slang 11.0.448 rejects it too.
module main;
  class no_tag;
  endclass
  class common #(type Treg = no_tag);
    static function int poke(); return Treg::tag(); endfunction
  endclass
  initial $display("%0d", common#(no_tag)::poke());
endmodule
