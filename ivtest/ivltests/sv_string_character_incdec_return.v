module sv_string_character_incdec_return;
  function automatic string recurse(input int depth);
    string inner;
    recurse = "A";
    if (depth) begin
      recurse[0]++;
      inner = recurse(depth-1);
      if (recurse != "B") $fatal(1, "outer return frame changed: %s", recurse);
      recurse = {inner, "A"};
    end
    ++recurse[0];
  endfunction
  initial begin
    string value;
    value = recurse(2);
    if (value != "DAA") $fatal(1, "return recursion=%s", value);
    $display("PASSED");
  end
endmodule
