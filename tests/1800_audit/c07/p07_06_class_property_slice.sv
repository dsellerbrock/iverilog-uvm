class holder;
  int values[];

  function void copy(input int source[]);
    values = source[0:0];
  endfunction
endclass

module test;
  int source[];
  holder h;

  initial begin
    source = new[2];
    source[0] = 41;
    source[1] = 42;
    h = new;
    h.copy(source);
    if (h.values.size() != 1 || h.values[0] != 41)
      $fatal(1, "class dynamic-array property did not receive the selected slice");
    $display("PASS §7.6 class-property dynamic-array slice assignment");
    $finish;
  end
endmodule
