// Extended differential negative (focus-only, not in the strict main lists):
// these IEEE randc provenance paths are diagnosed by Icarus, while Slang 11
// misses some of them or rejects the paren-less method-chain spelling.
typedef enum bit [1:0] {
  RANDC_PROV_EXT_A = 2'd0,
  RANDC_PROV_EXT_B = 2'd1
} randc_prov_ext_e;

class randc_prov_ext_leaf;
  randc randc_prov_ext_e e;
  randc int cyc;

  function randc_prov_ext_leaf id();
    return this;
  endfunction
endclass

class randc_prov_ext_ast;
  randc bit idx;
  rand bit arr[2];
  rand randc_prov_ext_leaf leaf;

  function automatic bit identity(input bit value);
    return value;
  endfunction

  constraint call_argument_bad { soft (identity(leaf.cyc) == 0); }
  constraint selected_index_bad { soft (arr[idx] == 0); }
  constraint parenless_call_bad { soft (leaf.id.cyc == 0); }
endclass

class randc_prov_ext_target;
  rand int values[2];
endclass

class randc_prov_ext_caller;
  randc int item;
  randc_prov_ext_target target;

  function automatic void compile_only();
    int local_reduction_bad = target.randomize() with {
      soft (values.sum() with (local::item) == 0);
    };
  endfunction
endclass

module top;
  randc_prov_ext_leaf obj;
  randc_prov_ext_leaf peer;
  randc_prov_ext_target target;

  function automatic randc_prov_ext_leaf peer_value();
    return peer;
  endfunction

  function automatic void compile_only();
    int returned_bad = target.randomize() with {
      soft (peer_value().cyc == 0);
    };
    int dotted_method_bad = target.randomize() with {
      soft (peer.id().cyc == 0);
    };
  endfunction
endmodule

package randc_prov_ext_pkg;
  typedef enum bit [1:0] {
    RANDC_PROV_EXT_PKG_A = 2'd0,
    RANDC_PROV_EXT_PKG_B = 2'd1
  } enum_t;

  class leaf;
    randc enum_t e;
  endclass

  leaf obj;
endpackage

class randc_prov_ext_flattened_calls;
  constraint hierarchy_enum_method_bad {
    soft (top.obj.e.next() == RANDC_PROV_EXT_A);
  }
  constraint package_enum_method_bad {
    soft (randc_prov_ext_pkg::obj.e.next() ==
      randc_prov_ext_pkg::RANDC_PROV_EXT_PKG_A);
  }
endclass

module test;
  randc_prov_ext_ast ast;
  randc_prov_ext_caller caller;
  randc_prov_ext_flattened_calls flattened;

  initial begin
    caller = new;
    caller.target = new;
    caller.compile_only();
  end
endmodule
