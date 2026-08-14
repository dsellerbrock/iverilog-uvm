// IEEE 1800-2017 8.24: out-of-block class method bodies may appear in the
// enclosing module scope. Cover constructors, functions, and tasks so the
// shared scoped-method grammar cannot silently support only one spelling.
module test;
  class counter_c;
    int value;

    extern function new(int seed);
    extern function int add(int amount);
    extern task bump(int amount);
  endclass

  function counter_c::new(int seed);
    value = seed;
  endfunction

  function int counter_c::add(int amount);
    value += amount;
    return value;
  endfunction

  task counter_c::bump(int amount);
    value += amount;
  endtask

  counter_c item;

  initial begin
    item = new(12);
    if (item.add(9) !== 21)
      $fatal(1, "module-scoped function body was not bound");
    item.bump(4);
    if (item.value !== 25)
      $fatal(1, "module-scoped task body was not bound");
    $display("PASSED");
  end
endmodule
