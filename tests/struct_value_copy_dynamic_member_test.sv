// Assigning one unpacked struct to another (`a = b;`) must copy the struct's
// dynamic members.  iverilog modelled an unpacked struct as an object but, on a
// struct-to-struct property assignment, did not recognise the NO_TYPE struct
// r-value as object-like and coerced it to a NULL object -- silently dropping
// the whole struct (the destination's assoc/darray members came up size 0).
// This is the OpenTitan aon_timer scoreboard pattern:
//   bfm_timed_regs_t prev_timed_regs, new_regs;   // r[timed_reg_e] assoc
//   prev_timed_regs = new_regs;
//
// Fix: a struct r-value is stored via %store/prop/obj/d, which deep-duplicates
// the object (vvp_cobject::duplicate copies each property; associative-array
// members are duplicated, giving value semantics).  Class-handle members keep
// reference semantics.
module struct_value_copy_dynamic_member_test;
  typedef enum { A, B, C } e_t;
  typedef struct { int r[e_t]; }           s_assoc_t;
  typedef struct { int d[]; bit [7:0] v; } s_darr_t;

  class item; int x; function new(int n); x=n; endfunction endclass

  class sb;
    s_assoc_t prev, cur;
    s_darr_t  pd, qd;
    item      h1, h2;
    function int run();
      // associative-array member: deep copy (independent of the source)
      cur.r[A]=10; cur.r[B]=20; cur.r[C]=30;
      prev = cur;
      if (!(prev.r.size()==3 && prev.r[A]==10 && prev.r[B]==20 && prev.r[C]==30)) return 0;
      cur.r[A]=99;
      if (prev.r[A] !== 10) return 0;          // destination independent

      // dynamic-array + scalar members: the copy carries the values across
      // (the whole struct was previously dropped to null)
      pd.d = new[3]; pd.d[0]=1; pd.d[1]=2; pd.d[2]=3; pd.v=8'hAB;
      qd = pd;
      if (!(qd.d.size()==3 && qd.d[0]==1 && qd.d[1]==2 && qd.d[2]==3 && qd.v==8'hAB)) return 0;

      // class-handle members keep REFERENCE semantics
      h1 = new(5); h2 = h1; h1.x = 8;
      if (h2.x !== 8) return 0;

      return 1;
    endfunction
  endclass

  initial begin
    sb s = new();
    if (s.run()) $display("PASS");
    else         $display("FAIL");
    $finish;
  end
endmodule
