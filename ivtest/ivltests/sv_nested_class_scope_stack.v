// IEEE 1800-2017 8.3: a class declaration may be a class item.  Parsing a
// nested declaration must restore the enclosing class so later properties and
// methods retain the right owner, including across more than one nesting level.
class outer_c;
  class inner_c;
    class deepest_c;
      int deepest_value;

      function new;
        deepest_value = 3;
      endfunction

      function int read;
        return deepest_value;
      endfunction
    endclass

    deepest_c deepest;
    int inner_value;

    function new;
      deepest = new;
      inner_value = 2;
    endfunction

    function int read;
      return inner_value + deepest.read();
    endfunction
  endclass

  inner_c inner;
  int outer_value;

  function new;
    inner = new;
    outer_value = 1;
  endfunction

  function int read;
    return outer_value + inner.read();
  endfunction
endclass

module test;
  outer_c item;

  initial begin
    item = new;
    if (item.read() !== 6)
      $fatal(1, "nested class scope was not restored");
    $display("PASSED");
  end
endmodule
