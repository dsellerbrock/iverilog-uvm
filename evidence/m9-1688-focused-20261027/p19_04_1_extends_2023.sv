module top;
  class base; bit [3:0] a;
    covergroup g1 with function sample(bit bb);
      ca: coverpoint a { bins lo = {[0:7]}; bins hi = {[8:15]}; }
      cb: coverpoint bb { bins z = {0}; bins o = {1}; }
    endgroup
    function new(); g1 = new; endfunction
  endclass
  class derived extends base; bit d;
    covergroup extends g1;
      cb: coverpoint bb { bins z = {0}; }
      cd: coverpoint d { bins z = {0}; bins o = {1}; }
    endgroup : g1
    function new(); super.new(); endfunction
  endclass
  base bo; derived dobj; real r;
  initial begin
    dobj = new; dobj.a = 3; dobj.d = 0; dobj.g1.sample(0); r = dobj.g1.get_inst_coverage();
    $display("%s 19.4.1.derived_replaces_overrides_adds cov=%f", (r > 66.6 && r < 66.7) ? "PASS" : "FAIL", r);
    bo = new; bo.a = 3; bo.g1.sample(0); r = bo.g1.get_inst_coverage();
    $display("%s 19.4.1.base_unchanged cov=%f", (r > 49.9 && r < 50.1) ? "PASS" : "FAIL", r);
  end
endmodule
