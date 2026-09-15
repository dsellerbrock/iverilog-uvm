module sv_const_string_character_write_runtime;
  string storage = "ABC";
  function automatic string mutate_nonlocal();
    storage[0] = "Z";
    return storage;
  endfunction
  initial begin
    if (mutate_nonlocal() != "ZBC" || storage != "ZBC")
      $fatal(1, "ordinary runtime non-local string write failed");
    $display("PASSED");
  end
endmodule
