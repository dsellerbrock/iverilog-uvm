// A value whose type has no vector representation, read in a vector
// context: an event handle assigned to a logic vector.
//
// The code generator used to substitute a zero for any value type it
// did not recognize and let the compile succeed -- and for
// IVL_VT_NO_TYPE it did so with no message at all. The simulation ran
// and read zero where the expression's value belonged.
module sv_vec4_bad_value_type;
  event e;
  logic [7:0] x;
  initial begin
    x = e;
    $display("FAILED -- should not have compiled, x = %h", x);
  end
endmodule
