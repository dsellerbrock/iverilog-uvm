// IEEE 1800-2017/2023 25.7 requires data_type_or_void in a modport function
// prototype. Unlike an ordinary function declaration, the return type may not
// be implicit.
interface implicit_return_if;
  function int query();
    return 1;
  endfunction

  modport rejected(import function query());
endinterface

module sv_modport_function_implicit_return_fail;
  implicit_return_if bus();
endmodule
