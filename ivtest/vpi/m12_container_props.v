// VPI visibility for runtime containers stored in class properties.
module top;
  class Inner;
    int q[$];
    int da[];
    int aa[string];
    string sq[$];
    real rd[];

    function new(int base = 0, bit fill = 1);
      int count = (base >= 200) ? 3 : 2;
      if (fill) begin
        q.push_back(base + 10);
        q.push_back(base + 11);
        if (count == 3)
          q.push_back(base + 12);
        da = new[count];
        da[0] = base + 20;
        da[1] = base + 21;
        if (count == 3)
          da[2] = base + 22;
        aa["b"] = base + 31;
        aa["a"] = base + 30;
        if (count == 3)
          aa["c"] = base + 32;
        sq.push_back("alpha");
        sq.push_back("beta");
        rd = new[2];
        rd[0] = 1.25 + base;
        rd[1] = 2.5 + base;
      end
    endfunction
  endclass

  class Holder;
    Inner inner;
    function new;
      inner = new(100);
    endfunction
  endclass

  Inner obj;
  Inner empty;
  Inner nil;
  Holder h;

  initial begin
    obj = new;
    empty = new(0, 0);
    empty.da = new[0];
    nil = new(0, 0);
    h = new;

    $m12_container_props_probe;

    // VPI writes through live class-property element handles.
    if (obj.q[1] != 111 || obj.da[0] != 120 ||
        obj.aa["a"] != 130 || obj.sq[0] != "from-vpi" ||
        obj.rd[1] != 9.5) begin
      $display("FAILED SV writeback q=%0d da=%0d aa=%0d sq='%s' rd=%f",
               obj.q[1], obj.da[0], obj.aa["a"], obj.sq[0], obj.rd[1]);
    end

    // A member handle must stay live across owner replacement.
    obj = new(200);
    $m12_container_props_reprobe;
    $finish(0);
  end
endmodule
