// IEEE 1800-2023 8.29, 8.30: weak_reference#(T) gives access to an object
// without keeping it alive.

class obj;
   int v = 7;
endclass

class ex_obj extends obj;
endclass

typedef weak_reference#(obj)	obj_ref;
typedef weak_reference#(ex_obj)	ex_obj_ref;

// A weak reference can sit inside another object and go through tasks
// and functions like any handle (8.30.1).
class keeper;
   obj_ref ref_;
   function new(obj_ref r); ref_ = r; endfunction
   function bit alive(); return ref_.get() != null; endfunction
endclass

package pkg;
   // The name can be reused outside std (8.30.1, 26.7).
   class weak_reference;
      function int get(); return 42; endfunction
   endclass
   function automatic int user_get();
      weak_reference w = new;
      return w.get();
   endfunction
endpackage

module top;
   integer fails = 0;

   task automatic check(input string name, input bit ok);
      if (!ok) begin
	 $display("FAILED: %s at time %0t", name, $time);
	 fails = fails + 1;
      end
   endtask

   obj s, s2, got;
   ex_obj e;
   obj_ref w1, w2, wn;
   ex_obj_ref we;
   std::weak_reference#(obj) wstd;
   keeper k;
   longint id_s, id_e;
   bit woke_clear, woke_gc;

   initial begin
      s = new; s2 = new; e = new;
      w1 = new(s); w2 = new(s); wn = new(null);

      // 8.30.2: every weak_reference is its own object.
      check("w1 != w2", w1 != w2);
      check("same referent", w1.get() == w2.get());
      check("referent is s", w1.get() == s);
      check("member through get()", w1.get().v == 7);
      check("new(null)", wn.get() == null);

      // 8.30.5: get_id.
      id_s = obj_ref::get_id(s);
      check("get_id(null) == 0", obj_ref::get_id(null) == 0);
      check("get_id(s) != 0", id_s != 0);
      check("get_id is stable", obj_ref::get_id(s) == id_s);
      check("get_id is unique", obj_ref::get_id(s2) != id_s);
      id_e = obj_ref::get_id(e);
      check("get_id through the base and the derived type",
	    id_e != 0 && ex_obj_ref::get_id(e) == id_e);

      // 8.30.4: clear() affects this weak reference only.
      w1.clear();
      check("cleared", w1.get() == null);
      check("the other one still refers to s", w2.get() == s);

      // 8.30.3 NOTE: a handle from get() is a strong reference.
      got = w2.get();
      s = null;
      check("kept alive by the handle from get()", w2.get() == got && got.v == 7);

      // 8.30.1: with no strong handle left the weak references are cleared.
      wstd = new(got);
      k = new(w2);
      check("keeper sees it", k.alive());
      got = null;
      check("reclaimed: w2", w2.get() == null);
      check("reclaimed: std::weak_reference", wstd.get() == null);
      check("reclaimed: seen through another object", !k.alive());

      // A derived object referenced through both types.
      we = new(e);
      w1 = new(e);
      check("derived via base type", w1.get() == e && we.get() == e);
      e = null;
      check("derived reclaimed", w1.get() == null && we.get() == null);

      // The weak_reference object itself is an ordinary object.
      w2 = null;
      check("s2 untouched", obj_ref::get_id(s2) != 0 && s2.v == 7);
      // The class scope can be named directly, with or without std::.
      check("direct class scope",
	    weak_reference#(obj)::get_id(s2) == obj_ref::get_id(s2)
	    && std::weak_reference#(obj)::get_id(s2) == obj_ref::get_id(s2));

      // 8.30.3: wait on get(), ended by clear() and by reclamation.
      s = new;
      w1 = new(s);
      w2 = new(s2);
      fork
	 begin wait (w1.get() == null); woke_clear = 1; end
	 begin wait (w2.get() == null); woke_gc = 1; end
      join_none
      #1 check("still waiting", !woke_clear && !woke_gc);
      w1.clear();
      #1 check("woken by clear()", woke_clear && !woke_gc);
      s2 = null;
      #1 check("woken by reclamation", woke_gc);

      check("user class of the same name", pkg::user_get() == 42);

      if (fails == 0)
	 $display("PASSED");
   end
endmodule
