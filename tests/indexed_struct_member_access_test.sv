// Indexed access to a member of an UNPACKED struct, where the member is a
// dynamic collection (associative array / dynamic array).  iverilog modeled
// the access via the class-property path and bailed with
//   "sorry: Indexed struct member access not yet supported"
// for any indexed tail component on a struct type.  This is the OpenTitan
// aon_timer_scoreboard pattern: a `bfm_timed_regs_t` struct whose member
//   uvm_reg_data_t r[aon_timer_intr_timed_regs::timed_reg_e];
// is read/written as `new_regs.r[r]` / `state.r[r] = ...` with a variable key.
//
// The fix routes an indexed UNPACKED-struct member through NetEProperty with
// the elaborated index as the property element-select, reusing the existing
// class-property array codegen.
module indexed_struct_member_access_test;
  typedef enum { A, B, C } e_t;
  typedef struct { int   r[e_t];   } s_assoc_t;   // unpacked: assoc member
  typedef struct { int   d[];      } s_darr_t;    // unpacked: darray member

  // Exercise inside a class (the OT scoreboard context).
  class sb;
    s_assoc_t a;
    s_darr_t  sd;
    function int run();
      e_t k = B;
      // variable-key WRITE then READ
      a.r[A] = 10;
      a.r[k] = 20;            // variable key write
      sd.d = new[3];
      sd.d[0] = 7; sd.d[2] = 9;
      if (a.r[A]==10 && a.r[k]==20 && a.r[B]==20 &&   // const + var key read
          sd.d[0]==7 && sd.d[2]==9 && sd.d.size()==3)
        return 1;
      $display("vals aA=%0d ak=%0d aB=%0d d0=%0d d2=%0d n=%0d",
               a.r[A], a.r[k], a.r[B], sd.d[0], sd.d[2], sd.d.size());
      return 0;
    endfunction
  endclass

  initial begin
    sb s = new();
    if (s.run()) $display("PASS");
    else         $display("FAIL");
    $finish;
  end
endmodule
