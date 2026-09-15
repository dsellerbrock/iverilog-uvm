// IEEE 1800-2017/2023 13.4.1: typed function-name return storage.
module sv_string_uarray_return_boundary;
  typedef string row_t[-1:0];
  row_t first, second;

  function automatic row_t make_string(input string suffix, input int which);
    make_string = '{-1: "left", 0: "right"};
    make_string[which] = {make_string[which], suffix};
    make_string[0] = {"[", make_string[0], "]"};
  endfunction

  initial begin
    first = make_string("!", -1);
    second = make_string("?", -1);
    if (first[-1] != "left!" || first[0] != "[right]"
        || second[-1] != "left?" || second[0] != "[right]")
      $fatal(1, "string indexed/compound return writes");
    first[-1] = "changed";
    if (second[-1] != "left?")
      $fatal(1, "string return arrays alias across calls");
    $display("PASSED");
  end
endmodule
