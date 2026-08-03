// IEEE 1800-2017 7.5/10.9.1: a dynamic array of class handles may be
// initialized from an assignment pattern. Every element keeps the handle
// returned by its expression; code generation previously rejected each one.
class item;
  int value;

  function new(int value);
    this.value = value;
  endfunction

  static function item make(int value);
    make = new(value);
  endfunction
endclass

module darray_class_pattern_test;
  item values[];

  initial begin
    values = '{item::make(11), item::make(22), item::make(33)};

    if (values.size() != 3)
      $fatal(1, "wrong dynamic-array size: %0d", values.size());
    foreach (values[i]) begin
      if (values[i] == null)
        $fatal(1, "null class handle at index %0d", i);
      if (values[i].value != (i + 1) * 11)
        $fatal(1, "wrong value at index %0d: %0d", i, values[i].value);
    end

    $display("DARRAY CLASS PATTERN TEST: PASS");
  end
endmodule
