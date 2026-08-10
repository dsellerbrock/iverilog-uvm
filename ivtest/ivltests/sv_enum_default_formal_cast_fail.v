// IEEE 1800-2017 6.19.3/6.19.4: numerical use converts enum members
// to the enum's base integral type. Converting that result back to the enum
// requires an explicit cast, including in a formal's default expression.
module sv_enum_default_formal_cast_fail;
  typedef enum int { A = 1, B = 2, AB = 3 } enum_t;

  function automatic enum_t invalid_default(
      input enum_t value = (A | B));
    return value;
  endfunction
endmodule
