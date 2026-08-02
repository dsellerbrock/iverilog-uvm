// IEEE 1800-2017 6.18: a const local declaration remains a declaration when
// it follows another block item. Parser declaration/statement ambiguity used
// to send this form into statement context and reject the `const` keyword.
package block_const_typedef_initializer_pkg;
  typedef logic [31:0] word_t;

  class field_t;
    function int get_pos();
      return 3;
    endfunction
  endclass

  class holder_t;
    field_t field;
    function new();
      field = new();
    endfunction
  endclass
endpackage

module block_const_typedef_initializer_test;
  import block_const_typedef_initializer_pkg::*;
  holder_t holder;

  task automatic check();
    word_t ordinary;
    const word_t constant_value = 1 << holder.field.get_pos();
    ordinary = constant_value;
    if (ordinary != 8) $fatal(1, "bad const initializer");
  endtask

  initial begin
    holder = new();
    check();
    $display("BLOCK CONST TYPEDEF INITIALIZER TEST: PASS");
  end
endmodule
