// IEEE 1800-2023 §8.30: weak references.
class obj; int v = 7; endclass
class ex_obj extends obj; endclass
typedef weak_reference#(obj) obj_ref;
typedef weak_reference#(ex_obj) ex_obj_ref;
module p08_30_weak; obj s, s2; ex_obj e; obj_ref w1, w2, wn; ex_obj_ref we;
  initial begin
    s = new; s2 = new; e = new;
    w1 = new(s); w2 = new(s); wn = new(null);
    $display("W1 %0d %0d", w1 != w2, w1.get() == w2.get());
    $display("W2 %0d", w1.get().v);
    $display("W4 %0d", wn.get() == null);
    $display("W5 %0d %0d %0d %0d", obj_ref::get_id(null) == 0, obj_ref::get_id(s) != 0,
             obj_ref::get_id(s) == obj_ref::get_id(s), obj_ref::get_id(s) != obj_ref::get_id(s2));
    $display("W5E %0d", obj_ref::get_id(e) == ex_obj_ref::get_id(e));
    w1.clear(); $display("W3 %0d %0d", w1.get() == null, w2.get() == s);
  end
endmodule
