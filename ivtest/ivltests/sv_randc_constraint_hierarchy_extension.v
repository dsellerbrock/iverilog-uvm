// Extended hierarchy control (focus-only): Icarus elaborates all roots and
// resolves top.obj / top.f here. Slang's `--top test` mode intentionally omits
// the separate top root, so this is not part of the strict main manifests.
typedef enum bit [1:0] {
  RANDC_HIER_A = 2'd0,
  RANDC_HIER_B = 2'd1
} randc_hier_e;

class randc_hier_plain_leaf;
  randc_hier_e e;
endclass

module top;
  randc_hier_plain_leaf obj;

  function automatic int f();
    return 1;
  endfunction

  initial obj = new;
endmodule

class randc_hier_control;
  constraint enum_method_ok { soft (top.obj.e.next() == RANDC_HIER_A); }
  constraint function_ok { soft (top.f() == 1); }
endclass

module test;
  randc_hier_control control;

  initial begin
    control = new;
    $display("PASSED");
  end
endmodule
