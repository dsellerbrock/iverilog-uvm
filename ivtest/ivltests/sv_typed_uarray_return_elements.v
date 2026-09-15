// Fixed unpacked-array function results use emitted automatic array storage.
// Exercise typed element writes and reads in the function body, then verify
// the caller-side array copy for real and string elements.
module sv_typed_uarray_return_elements;
  typedef real real_pair_t[2];
  typedef string string_pair_t[2];

  function automatic real_pair_t make_real(input real base);
    for (int i = 0; i < 2; i++)
      make_real[i] = base + i;
  endfunction

  function automatic string_pair_t make_string();
    for (int i = 0; i < 2; i++)
      make_string[i] = i == 0 ? "left" : "right";
  endfunction

  real_pair_t reals;
  string_pair_t strings;

  initial begin
    reals = make_real(1.5);
    strings = make_string();
    if (reals[0] != 1.5 || reals[1] != 2.5)
      $fatal(1, "wrong real return: %g %g", reals[0], reals[1]);
    if (strings[0] != "left" || strings[1] != "right")
      $fatal(1, "wrong string return: %s %s", strings[0], strings[1]);

    // A second invocation proves that automatic return-array storage is
    // refreshed and copied before its function frame is released.
    reals = make_real(7.25);
    strings = make_string();
    if (reals[0] != 7.25 || reals[1] != 8.25)
      $fatal(1, "wrong repeated real return: %g %g", reals[0], reals[1]);
    if (strings[0] != "left" || strings[1] != "right")
      $fatal(1, "wrong repeated string return");
    $display("PASSED");
  end
endmodule
