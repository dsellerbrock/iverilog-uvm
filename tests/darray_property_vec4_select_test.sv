// Regression: reading an element of a dynamic-array (or queue) CLASS PROPERTY
// in a vec4 context, e.g. `case (states[i])` where `states` is a class member
// `state_e states[]` (OpenTitan i2c_glitch_vseq.sv:309). The vec4 select
// codegen (draw_select_vec4) assumed the indexed dynamic-array expression was
// always a plain signal and asserted on ivl_expr_signal(); a class-property
// access (NetEProperty) is not a signal, so it crashed:
//   eval_vec4.c: draw_select_vec4: Assertion `sig' failed.
// The non-signal case now evaluates the array as an object and loads the
// element with %load/dar/obj/vec4 (which peeks the base vvp_darray, covering
// both dynamic arrays and queues).
typedef enum bit [1:0] { A, B, C } st_e;
class c;
  st_e states[];
  function void init();
    states = new[3];
    states[0] = A; states[1] = B; states[2] = C;
  endfunction
  function int t();
    int n = 0;
    foreach (states[i])
      case (states[i])          // darray-property element read in vec4/case
        A: n += 1;
        B: n += 10;
        C: n += 100;
      endcase
    return n;
  endfunction
endclass
module top;
  initial begin
    c o = new();
    o.init();
    if (o.states.size() == 3 && o.t() == 111) $display("PASS");
    else $display("FAIL size=%0d val=%0d", o.states.size(), o.t());
  end
endmodule
