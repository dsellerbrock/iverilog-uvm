// The remaining M1B-3 fallback is hardcoded to the class name
// `uvm_shared` with property `value` and type parameter `T`. If the
// SAME shape works under a DIFFERENT class name, the general path
// already resolves it and the hack is dead code.
class my_shared #(type T = int);
  T value;
endclass
typedef int iq_t[$];
typedef int ia_t[];
module top;
  initial begin
    my_shared #(iq_t) q = new;
    my_shared #(ia_t) d = new;
    int ok = 1;
    q.value.push_back(7); q.value.push_back(9);
    if (q.value[1] != 9) begin $display("FAIL queue idx got %0d", q.value[1]); ok = 0; end
    if (q.value.size() != 2) begin $display("FAIL queue size %0d", q.value.size()); ok = 0; end
    d.value = new[3];
    d.value[2] = 5;
    if (d.value[2] != 5) begin $display("FAIL darray idx got %0d", d.value[2]); ok = 0; end
    if (ok) $display("PASS m1b3_generic (general path resolves; hack is dead)");
    $finish(0);
  end
endmodule
