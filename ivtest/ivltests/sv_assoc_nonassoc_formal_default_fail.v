// A cached default for an ordinary container is still checked against the
// formal type even when the subroutine is never called.
module sv_assoc_nonassoc_formal_default_fail;
  typedef int assoc_t[string];

  function automatic bit accepts(input int value[$] =
                                      assoc_t'{default:1});
    return value.size() == 0;
  endfunction
endmodule
