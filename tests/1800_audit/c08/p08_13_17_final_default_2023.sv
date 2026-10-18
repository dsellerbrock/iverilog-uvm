module top;
  class Base; string name; int id;
    function new(string name, int id = 3); this.name = name; this.id = id; endfunction endclass
  class A extends Base; function new(default); endfunction endclass
  class B extends Base; int size;
    function new(int size, default); super.new(default); this.size = size; endfunction endclass
  class C extends B; bit enable;
    function new(default, bit enable); super.new(default); this.enable = enable; endfunction endclass
  class D extends Base(default); endclass
  class :final F extends Base; function new(); super.new("f"); endfunction endclass
  A a; B b; C c; D d; F f;
  initial begin
    a = new("a", 4); b = new(9, "b"); c = new(2, "c", 6, 1); d = new("d"); f = new;
    $display("%s 8.17.default_A", (a.name == "a" && a.id == 4) ? "PASS" : "FAIL");
    $display("%s 8.17.default_B", (b.size == 9 && b.name == "b" && b.id == 3) ? "PASS" : "FAIL");
    $display("%s 8.17.default_C", (c.size == 2 && c.name == "c" && c.id == 6 && c.enable) ? "PASS" : "FAIL");
    $display("%s 8.17.extends_default", (d.name == "d" && d.id == 3) ? "PASS" : "FAIL");
    $display("%s 8.13.final_instantiable", f.name == "f" ? "PASS" : "FAIL");
  end
endmodule
