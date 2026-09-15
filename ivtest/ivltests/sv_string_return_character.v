module sv_string_return_character;
  int index_calls, rhs_calls;
  function automatic int index_once(input int value); index_calls++; return value; endfunction
  function automatic int rhs_once(); rhs_calls++; return 1; endfunction
  function automatic string plain_update();
    plain_update = "ABC";
    plain_update[index_once(1)] = "Z";
  endfunction
  function automatic string compound_update();
    compound_update = "ABC";
    compound_update[index_once(1)] += rhs_once();
  endfunction
  initial begin
    string plain;
    string compound;
    plain = plain_update();
    compound = compound_update();
    if (plain != "AZC" || compound != "ACC" || index_calls != 2 || rhs_calls != 1)
      $fatal(1, "plain=%s compound=%s index=%0d rhs=%0d", plain, compound, index_calls, rhs_calls);
    $display("PASSED");
  end
endmodule
