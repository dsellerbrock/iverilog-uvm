typedef struct packed { int value; } unit_word_t;
unit_word_t word = '{5};

`ifndef ISSUE3772_LEGAL
let L() = 11;
let bare_unit = 13;

function int unit_function(int value);
  return 20 + value;
endfunction
`endif

package provider;
  let increment(value) = value + 1;
endpackage

package template_pkg;
  import provider::increment;
  let formal(word) = word + 1;
  let formal_default(word, second = word) = second;
  let imported(value) = increment(value);

`ifndef ISSUE3772_LEGAL
  let combine(actual) = word.value + actual;
  let with_default(actual = word.value) = actual;
  let read_unit_function(actual) = unit_function(actual);
  // This declaration has no use site and its select is a formal.
  let unused(bit_index) = word.value[bit_index];
  let through_unit_let() = $unit::L();

  function int from_unit_let();
    return $unit::L() + $unit::bare_unit;
  endfunction

  function int twice();
    return combine(1) + combine(2) + through_unit_let();
  endfunction
`endif
endpackage

module test;
  int word = 7;

  function int unit_function(int value);
    return 100 + value;
  endfunction

  initial begin
    if (template_pkg::formal(word) !== 8 ||
        template_pkg::formal_default(word) !== 7 ||
        template_pkg::imported(word) !== 8)
      $fatal(1, "a formal or imported package let bound incorrectly");

`ifndef ISSUE3772_LEGAL
    if (template_pkg::from_unit_let() !== 24 ||
        template_pkg::combine(word) !== 12 ||
        template_pkg::with_default() !== 5 ||
        template_pkg::with_default(word) !== 7 ||
        template_pkg::read_unit_function(word) !== 27 ||
        template_pkg::through_unit_let() !== 11 ||
        template_pkg::twice() !== 24)
      $fatal(1, "unit references or caller arguments bound incorrectly");
`endif

    $display("PASSED");
  end
endmodule
