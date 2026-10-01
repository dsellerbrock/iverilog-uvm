class cov_t;
  bit op, ready;
  covergroup control_cg;
    type_option.merge_instances = 0;
    option.get_inst_coverage = 1;
    op_evict_cp: coverpoint op {
      bins zero = {0};
      bins one = {1};
      bins rise = (0 => 1);
    }
    ready_cp: coverpoint ready { bins yes = {0}; }
  endgroup
  covergroup cross_cg;
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    op_cp: coverpoint op;
    ready_cp: coverpoint ready;
    op_ready_x: cross op_cp, ready_cp;
  endgroup
  function new;
    control_cg = new;
    cross_cg = new;
  endfunction
endclass

class seq_t;
  cov_t cov;
  function new;
    cov = new;
  endfunction
  function real point_type;
    return cov.control_cg.op_evict_cp.get_coverage();
  endfunction
  function real point_inst;
    return cov.control_cg.op_evict_cp.get_inst_coverage();
  endfunction
  function real group_type;
    return cov.control_cg.get_coverage();
  endfunction
  function real group_inst;
    return cov.control_cg.get_inst_coverage();
  endfunction
  function real cross_type;
    return cov.cross_cg.op_ready_x.get_coverage();
  endfunction
  function real cross_inst;
    return cov.cross_cg.op_ready_x.get_inst_coverage();
  endfunction
endclass

module top;
  seq_t a, b;
  task automatic ck(string label, real got, real want);
    if (!(got > want-0.00001 && got < want+0.00001))
      $fatal(1, "%s got %f expected %f", label, got, want);
  endtask
  initial begin
    a = new;
    b = new;
    a.cov.op = 0;
    a.cov.ready = 0;
    a.cov.control_cg.sample();
    ck("a point inst", a.point_inst(), 100.0/3.0);
    ck("b point inst", b.point_inst(), 0.0);
    ck("a point type", a.point_type(), 50.0/3.0);
    ck("b point type", b.point_type(), 50.0/3.0);
    ck("a group inst", a.group_inst(), 200.0/3.0);
    ck("b group inst", b.group_inst(), 0.0);
    ck("group type", a.group_type(), 100.0/3.0);
    a.cov.cross_cg.sample();
    ck("nested cross type", a.cross_type(), 25.0);
    ck("nested cross inst", a.cross_inst(), 25.0);
    $display("PASSED");
  end
endmodule
