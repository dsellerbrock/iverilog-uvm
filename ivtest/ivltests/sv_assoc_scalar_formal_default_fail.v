// A typed associative value is not a valid cached default for a scalar
// formal, even when the subroutine is never called.
module sv_assoc_scalar_formal_default_fail;
  typedef int assoc_t[string];

  function automatic int accepts(input int value =
                                      assoc_t'{default:1});
    return value;
  endfunction
endmodule
