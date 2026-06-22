// A type cast whose target is a class-scoped type: "my_class::some_enum_e'(expr)".
// The OpenTitan usbdev_scoreboard "loosely-timed registers" predictor uses this
// (e.g. r[usbdev_timed_regs::timed_reg_e'(TimedConfigIn0 + ep)]).  Without it the
// cast is taken as a *size* cast (class::member read as a width), failing with
// "Cast size expression must be constant".  Companion to the assoc-index fix
// (assoc_class_scoped_index_test): the lexer resolves "class::type" to a single
// token when it is immediately followed by "'" or "]".
class keys;
  typedef enum { K_A, K_B, K_C, K_D } key_e;
endclass

class regfile;
  int data[keys::key_e];
  function void load();
    // direct class-scoped type cast
    keys::key_e k = keys::key_e'(2);          // -> K_C
    data[k] = 30;
    // cast result used directly as an associative-array index (usbdev shape)
    data[keys::key_e'(0)] = 10;               // -> K_A
    data[keys::key_e'(1)] = 20;               // -> K_B
  endfunction
endclass

module class_scoped_cast_test;
  initial begin
    regfile rf = new();
    rf.load();
    if (rf.data[keys::K_A] == 10 &&
        rf.data[keys::K_B] == 20 &&
        rf.data[keys::K_C] == 30 &&
        rf.data.size()     == 3)
      $display("PASS size=%0d", rf.data.size());
    else
      $display("FAIL a=%0d b=%0d c=%0d size=%0d",
               rf.data[keys::K_A], rf.data[keys::K_B],
               rf.data[keys::K_C], rf.data.size());
    $finish;
  end
endmodule
