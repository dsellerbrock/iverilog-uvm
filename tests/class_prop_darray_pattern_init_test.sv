// Regression: a class-property dynamic array or queue initialized with an
// assignment pattern, e.g.
//   state_e states[] = '{A, B, C};   // OpenTitan i2c_glitch_vseq addr_states
//   int     q[$]     = '{1, 2, 3};
// (or assigned in new()/a method: `states = '{...}`). The pattern was lost --
// the array came up empty (size 0) -- because draw_eval_object handled only
// class aggregates; a dynamic-array/queue array-pattern fell through to its
// first element and produced a null object. eval_object_array_pattern now
// builds and populates the dynamic-array/queue object from the pattern.
typedef enum bit [1:0] { A, B, C } st_e;
class c;
  st_e states[] = '{A, B, C};
  int  q[$]     = '{1, 2, 3};
  string s[]    = '{"x", "y"};
  function void reassign();
    states = '{C, B, A};            // pattern assign in a method
  endfunction
endclass
module top;
  int errors = 0;
  initial begin
    c o = new();
    if (o.states.size() != 3) errors++;
    if (o.states[0] != A || o.states[2] != C) errors++;
    if (o.q.size() != 3 || o.q[1] != 2) errors++;
    if (o.s.size() != 2 || o.s[1] != "y") errors++;
    o.reassign();
    if (o.states.size() != 3 || o.states[0] != C || o.states[2] != A) errors++;
    if (errors == 0) $display("PASS");
    else $display("FAIL (%0d errors)", errors);
  end
endmodule
