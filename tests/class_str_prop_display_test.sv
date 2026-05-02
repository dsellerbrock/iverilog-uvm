// Phase 47: $display("%s", c.s) where c.s is a class string property used to
// emit the class type name (left-padded to its char length) instead of the
// property's actual value. tgt-vvp's get_vpi_taskfunc_signal_arg was returning
// the class instance signal handle, which VPI then read as a vpiStringVal of
// the type name. The fix returns 0 for IVL_EX_PROPERTY of string type so the
// caller falls into draw_eval_string and pushes the actual string value onto
// the str_stack for VPI to consume.

class C;
  string s = "hello";
endclass

module top;
  C c;
  initial begin
    c = new();
    $display("c.s=[%s] len=%0d", c.s, c.s.len());
    if (c.s == "hello") $display("PASS");
    else $display("FAIL got=[%s]", c.s);
    $finish;
  end
endmodule
