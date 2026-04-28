// Phase 49: rand <enum_type> property now picks values from the enum's
// label set, not random 32-bit bits. iverilog auto-generates a synthetic
// `inside` constraint per rand enum property at class elaboration so the
// existing Z3 path constrains the property to valid labels.

typedef enum int {
  ValA = 1000,
  ValB = 5000,
  ValC = 100000
} my_enum_e;

class C;
  rand my_enum_e e;
endclass

module top;
  initial begin
    int n_pass = 0;
    int n_fail = 0;
    int i;
    C ch;
    ch = new();
    for (i = 0; i < 20; i++) begin
      void'(ch.randomize());
      case (ch.e)
        ValA, ValB, ValC: n_pass++;
        default: n_fail++;
      endcase
    end
    if (n_fail == 0) $display("PASS %0d/%0d", n_pass, n_pass + n_fail);
    else $display("FAIL: %0d/%0d had invalid enum values", n_fail, n_pass + n_fail);
    $finish;
  end
endmodule
