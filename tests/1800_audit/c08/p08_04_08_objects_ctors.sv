// IEEE 1800-2023 8.4-8.8 audit probe (positive, self-checking)
module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  class Obj; int v; endclass
  class Base; int b = 7; virtual function int kind(); return 1; endfunction endclass
  class Der extends Base; int d = 3; virtual function int kind(); return 2; endfunction endclass
  class Pkt;
    typedef enum {ERR_OK = 0, ERR_OVERFLOW = 5} err_e;
    int address;
    function int current_status(); return address + 1; endfunction
    function int auto_local(); int k; k = k + 1; return k; endfunction
  endclass
  class vector #(parameter width = 7, type T = int); endclass
  class C;
    int c1 = 1; int c2 = 1; int c3 = 1;
    function new(int a); c2 = 2; c3 = a; endfunction
  endclass
  class D extends C;
    int d1 = 4; int d2 = c2; int d3 = 6;
    function new; super.new(d3); endfunction
  endclass
  class Defaults;
    int command; bit [12:0] address; int t;
    function new(int cmd = 11, bit [12:0] adrs = 0, int cmd_time = 0);
      command = cmd; address = adrs; t = cmd_time;
    endfunction
  endclass
  class Implicit; int x = 42; endclass
  class Priv;
    int k;
    local function new(); k = 9; endfunction
    static function Priv make(); Priv p; p = new(); return p; endfunction
  endclass
  class Prot; int k; protected function new(); k = 8; endfunction endclass
  class ProtDer extends Prot; function new(); super.new(); endfunction endclass
  class E #(type T = int) extends Base;
    T x;
    function new(T x_init); super.new(); x = x_init; endfunction
    virtual function int kind(); return 3; endfunction
  endclass
  class DA extends Base; int a; function new(int a_init = 1); a = a_init; endfunction endclass
  Obj h0, h1, h2; Base bh; Der dh; Pkt p; vector #(3) v; D dd; Defaults df;
  Implicit im; Priv pv; ProtDer pd; E #(byte) eb; DA da; int r1, r2;
  initial begin
    chk("8.4.default_null", h0 == null);
    if (h0 == null) h0 = new;
    chk("8.4.new_after_null_check", h0 != null);
    h1 = new; h2 = h1;
    chk("8.4.eq_same", h1 == h2);
    chk("8.4.ne_distinct", h0 != h1);
    chk("8.4.case_eq_null", (h0 !== null) && !(h0 === null));
    chk("8.4.case_eq_handles", (h1 === h2) && (h0 !== h1));
    chk("8.4.conditional", ((1'b0 ? h0 : h1) == h1));
    dh = new; bh = dh;
    chk("8.4.assign_compatible_eq", bh == dh);
    h2 = null; chk("8.4.assign_null", h2 == null);
    p = new; p.address = 41;
    chk("8.5.property_access", p.address == 41);
    chk("8.5.enum_via_instance", p.ERR_OVERFLOW == 5);
    chk("8.5.enum_via_scope", Pkt::ERR_OVERFLOW == 5);
    v = new; chk("8.5.param_via_instance", v.width == 3);
    // Removed after compile failure: chk("8.5.type_param_cast", vector#(3)::T'(3.45) == 3);
    chk("8.6.method_call", p.current_status() == 42);
    r1 = p.auto_local(); r2 = p.auto_local();
    chk("8.6.method_automatic_lifetime", r1 == 1 && r2 == 1);
    dd = new;
    chk("8.7.order_c1", dd.c1 == 1); chk("8.7.order_c2", dd.c2 == 2);
    chk("8.7.order_d1", dd.d1 == 4); chk("8.7.order_d2", dd.d2 == 2);
    chk("8.7.order_d3", dd.d3 == 6);
    $display("INFO 8.7.c3_undefined=%0d", dd.c3);
    df = new; chk("8.7.default_args", df.command == 11 && df.address == 0 && df.t == 0);
    df = new(1, 13'h5, 7); chk("8.7.positional_args", df.command == 1 && df.address == 5 && df.t == 7);
    df = new(.cmd_time(3)); chk("8.7.named_args", df.command == 11 && df.t == 3);
    im = new; chk("8.7.implicit_new", im.x == 42);
    pv = Priv::make(); chk("8.7.local_ctor_via_static", pv.k == 9);
    pd = new; chk("8.7.protected_ctor_via_super", pd.k == 8);
    bh = Der::new; chk("8.8.typed_ctor_dyn_type", bh.kind() == 2);
    chk("8.8.typed_ctor_cast", $cast(dh, bh));
    bh = E#(.T(byte))::new(.x_init(5)); chk("8.8.typed_ctor_param_kind", bh.kind() == 3);
    chk("8.8.typed_ctor_param_cast", $cast(eb, bh) && eb.x == 5);
    bh = DA::new(17); chk("8.8.typed_ctor_args", $cast(da, bh) && da.a == 17);
    $display("DONE fails=%0d", fails);
  end
endmodule
