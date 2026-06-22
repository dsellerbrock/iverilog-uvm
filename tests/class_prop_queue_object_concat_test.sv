// Concatenation of queues-of-objects assigned to a class property:
//   mapped = {mapped, mem};     // OpenTitan dv_base_reg_block.compute_*
// where the queue element is an object-like type (a class handle or an
// unpacked struct / cobject).
//
// eval_object_array_pattern (object-context queue build) treated each concat
// operand as a single element and emitted "%set/dar/obj/obj" followed by a
// "%pop/obj 1, 0".  But %set/dar/obj/obj already pops the value and leaves the
// destination queue on the object stack, so the extra %pop popped the
// destination -- the next operand then landed on the wrong object (a cobject)
// and crashed ("of_SET_DAR_OBJ_OBJ: Assertion `darray' failed").  This broke
// BOTH a genuine multi-element object pattern '{a, b} and a queue
// concatenation {q1, q2}.
//
// Fix: drop the bogus %pop/obj, and when an operand is itself a queue/darray
// (a concatenation, not a plain pattern) splice its elements onto the result
// queue with the new %append/qobj/stk/obj opcode (reuses append_qobj_elements_).
module class_prop_queue_object_concat_test;

  // --- object element = class handle ---
  class item;
    int v;
    function new(int x); v = x; endfunction
  endclass

  class hblk;
    item q[$], extra[$];
    function int run();
      item a = new(1), b = new(2), c = new(3);
      // genuine multi-element object pattern (the %pop/obj crash)
      q = '{a, b};
      if (!(q.size()==2 && q[0].v==1 && q[1].v==2)) return 0;
      // queue-of-handles self-concatenation
      extra.push_back(c);
      q = {q, extra};
      if (!(q.size()==3 && q[0].v==1 && q[1].v==2 && q[2].v==3)) return 0;
      return 1;
    endfunction
  endclass

  // --- object element = unpacked struct (cobject); the OT addr_range_t shape ---
  typedef struct { bit [63:0] s; } r_t;
  class sblk;
    r_t mapped[$], mem[$];
    function int run();
      r_t m0, m1, e0;
      m0.s = 10; m1.s = 20; e0.s = 30;
      mapped.push_back(m0); mapped.push_back(m1);
      mem.push_back(e0);
      mapped = {mapped, mem};          // self-concat, class-property
      if (!(mapped.size()==3 && mapped[0].s==10 && mapped[1].s==20
            && mapped[2].s==30)) return 0;
      return 1;
    endfunction
  endclass

  initial begin
    hblk h = new();
    sblk s = new();
    if (h.run() && s.run()) $display("PASS");
    else                    $display("FAIL h=%0d s=%0d", h.run(), s.run());
    $finish;
  end
endmodule
