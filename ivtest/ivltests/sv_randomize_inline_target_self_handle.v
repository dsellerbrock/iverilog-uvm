// IEEE 1800-2017/2023 18.7: a caller name that denotes the randomize target
// still reaches the target's rand handle and the child's rand property.
class inline_target_leaf;
  rand bit [7:0] value;
endclass

class inline_target_item;
  rand inline_target_leaf h;
endclass

module sv_randomize_inline_target_self_handle;
  inline_target_item a, al;
  int ok;

  initial begin
    a = new;
    a.h = new;
    a.h.value = 8'd104;
    al = a;

    ok = a.randomize() with { a.h.value == 5; };
    if (!ok || a.h.value != 8'd5)
      $fatal(1, "target handle name did not constrain rand child: ok=%0d value=%0d",
             ok, a.h.value);

    ok = a.randomize() with { al.h.value == 7; };
    if (!ok || a.h.value != 8'd7)
      $fatal(1, "alias handle name did not constrain rand child: ok=%0d value=%0d",
             ok, a.h.value);

    $display("PASSED");
  end
endmodule
