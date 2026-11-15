// IEEE 1800-2023 19.4.1: a derived covergroup has its base's sample()
// arguments. Its added and overriding coverpoints may use them, also when
// the group is sampled from a base-class method or through a base-class
// handle.
module top;
  int errors = 0;
  task automatic check(string what, real got, real want);
    if (got < want - 0.01 || got > want + 0.01) begin
      errors += 1;
      $display("FAILED %s: %0.2f, expected %0.2f", what, got, want);
    end
  endtask

  class base;
    bit [3:0] a;
    covergroup g1 with function sample(bit bb, int n);
      option.per_instance = 1;
      ca: coverpoint a { bins lo = {[0:7]}; bins hi = {[8:15]}; }
      cb: coverpoint bb { bins z = {0}; bins o = {1}; }
    endgroup
    function new(); g1 = new; endfunction
    function void smp(bit v, int n); g1.sample(v, n); endfunction
  endclass

  class derived extends base;
    bit d;
    covergroup extends g1;
      cb: coverpoint bb { bins z = {0}; }           // override reads the inherited argument
      cd: coverpoint d { bins z = {0}; bins o = {1}; }
      cn: coverpoint n + d { bins v[] = {[0:3]}; }  // an argument in an expression
    endgroup : g1
    function new(); super.new(); endfunction
    function void dsmp(bit v, int n); g1.sample(v, n); endfunction
  endclass

  class third extends derived;
    bit t;
    covergroup extends g1;
      ct: coverpoint bb ^ t { bins z = {0}; bins o = {1}; }
    endgroup
    function new(); super.new(); endfunction
  endclass

  // a base group that also has constructor arguments
  class cbase;
    covergroup g (int hi) with function sample(int v);
      pv: coverpoint v { bins b[] = {[0:hi]}; }
    endgroup
    function new(); g = new(1); endfunction
  endclass
  class cderived extends cbase;
    bit e;
    covergroup extends g;
      pe: coverpoint e;
      pw: coverpoint v { bins two = {2}; bins three = {3}; }
    endgroup
    function new(); super.new(); endfunction
  endclass

  base b0, h; derived d0; third t0; cbase ch; cderived cd0;
  initial begin
    // from a method of the derived class
    d0 = new; d0.a = 3; d0.d = 0; d0.dsmp(0, 2);
    check("derived cb", d0.g1.cb.get_inst_coverage(), 100.0);
    check("derived cn", d0.g1.cn.get_inst_coverage(), 25.0);
    check("derived", d0.g1.get_inst_coverage(), 56.25);    // ca 50, cb 100, cd 50, cn 25
    // through a base-class handle: bb = 1 misses the override's only bin
    d0 = new; h = d0; d0.a = 9; d0.d = 1; h.g1.sample(1, 2);
    check("handle cb", d0.g1.cb.get_inst_coverage(), 0.0);
    check("handle cd", d0.g1.cd.get_inst_coverage(), 50.0);
    check("handle cn", d0.g1.cn.get_inst_coverage(), 25.0);  // n + d = 3
    h.g1.sample(0, 0);
    check("handle cb 2", d0.g1.cb.get_inst_coverage(), 100.0);
    check("handle cn 2", d0.g1.cn.get_inst_coverage(), 50.0);  // 3 and 1
    // from a base-class method
    d0 = new; d0.d = 1; d0.smp(0, 1);
    check("method cb", d0.g1.cb.get_inst_coverage(), 100.0);
    check("method cn", d0.g1.cn.get_inst_coverage(), 25.0);  // 2
    check("method", d0.g1.get_inst_coverage(), 56.25);
    // a derived group as the base of another, through the root handle
    t0 = new; h = t0; t0.t = 1; t0.d = 0; h.g1.sample(0, 3);
    check("third ct", t0.g1.ct.get_inst_coverage(), 50.0);   // 0 ^ 1
    check("third cn", t0.g1.cn.get_inst_coverage(), 25.0);
    check("third cb", t0.g1.cb.get_inst_coverage(), 100.0);
    h.g1.sample(1, 3);
    check("third ct 2", t0.g1.ct.get_inst_coverage(), 100.0);
    // the base type is unchanged and separate
    b0 = new; b0.a = 3; b0.g1.sample(0, 0);
    check("base", b0.g1.get_inst_coverage(), 50.0);
    check("base type", b0.g1.get_coverage(), 50.0);
    // constructor arguments on the base group
    cd0 = new; ch = cd0; cd0.e = 1; ch.g.sample(2);
    check("ctor pe", cd0.g.pe.get_inst_coverage(), 50.0);
    check("ctor pw", cd0.g.pw.get_inst_coverage(), 50.0);
    check("ctor pv", cd0.g.pv.get_inst_coverage(), 0.0);
    if (errors == 0) $display("PASSED");
  end
endmodule
