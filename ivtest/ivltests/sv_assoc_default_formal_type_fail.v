// A formal default is checked against the formal's complete associative type.
module sv_assoc_default_formal_type_fail;
  typedef int int_by_string_t[string];
  typedef string string_by_string_t[string];

  function automatic bit accepts(
      input int_by_string_t value =
          string_by_string_t'{default:"bad formal default"});
    return value.size() == 0;
  endfunction
endmodule
