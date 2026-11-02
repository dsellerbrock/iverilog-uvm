module tb;
  class leaf;
    rand bit [7:0] value;
  endclass

  class c_t;
    rand leaf h;
  endclass

  c_t a = new, al;
  int ok;

  initial begin
    a.h = new;
    a.h.value = 8'd104;
    al = a;
    ok = a.randomize() with { a.h.value == 5; };
    if (ok !== 1 || a.h.value !== 8'd5)
      $fatal(1, "target name: ok=%0d a.h.value=%0d", ok, a.h.value);
    $display("target name: ok=%0d a.h.value=%0d", ok, a.h.value);

    ok = a.randomize() with { al.h.value == 7; };
    if (ok !== 1 || a.h.value !== 8'd7)
      $fatal(1, "alias: ok=%0d a.h.value=%0d", ok, a.h.value);
    $display("alias:       ok=%0d a.h.value=%0d", ok, a.h.value);
  end
endmodule
