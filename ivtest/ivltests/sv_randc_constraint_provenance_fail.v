// Slang-clean strict negative: every soft constraint below reaches a randc
// variable through an AST or name-resolution path diagnosed by both tools.
// Each source construct must be diagnosed once, even if elaboration clones or
// unrolls the expression. Slang gaps live in the extension-only fixtures.
typedef enum bit [1:0] {
  RANDC_PROV_BAD_A = 2'd0,
  RANDC_PROV_BAD_B = 2'd1
} randc_prov_bad_e;

class randc_prov_bad_leaf;
  randc randc_prov_bad_e e;
  // Slang 11 itself crashes while diagnosing a method-returned narrow randc
  // member. Keep this leaf integral but wide so the differential polarity is
  // fail-loud; Icarus also emits its documented 20-bit cycle-cap warning.
  randc int cyc;

  function randc_prov_bad_leaf id();
    return this;
  endfunction
endclass

class randc_prov_bad_ast;
  randc bit idx;
  rand bit pick;
  rand bit arr[2];
  rand randc_prov_bad_leaf a;
  rand randc_prov_bad_leaf b;

  function automatic bit identity(input bit value);
    return value;
  endfunction

  function randc_prov_bad_leaf get_leaf();
    return null;
  endfunction

  constraint cast_member_bad {
    soft (randc_prov_bad_leaf'(a).cyc == 0);
  }
  constraint ternary_member_bad { soft ((pick ? a : b).cyc == 0); }
  constraint child_call_bad { soft (a.id().cyc == 0); }
  constraint owner_method_call_bad { soft (get_leaf().cyc == 0); }
  constraint foreach_body_bad {
    foreach (arr[i]) soft (idx == 0);
  }
endclass

class randc_prov_bad_box #(type T = randc_prov_bad_leaf);
  static T obj;
endclass

class randc_prov_bad_specialization;
  rand bit x;
  constraint selected_specialization_bad {
    soft (randc_prov_bad_box#(randc_prov_bad_leaf)::obj.id().cyc == 0);
  }
endclass

package randc_prov_bad_pkg;
  class leaf;
    randc bit [1:0] cyc;
  endclass

  leaf peer;

  class self_user;
    rand bit x;
    constraint package_self_bad {
      soft (randc_prov_bad_pkg::peer.cyc == 0);
    }
  endclass
endpackage

import randc_prov_bad_pkg::*;

class randc_prov_bad_package_user;
  rand bit x;
  constraint package_qualified_bad {
    soft (randc_prov_bad_pkg::peer.cyc == 0);
  }
  constraint package_imported_bad { soft (peer.cyc == 0); }
endclass

class randc_prov_bad_target;
  rand bit x;
  rand bit values[2];
endclass

class randc_prov_bad_caller;
  randc bit i;
  randc_prov_bad_leaf peer;
  randc_prov_bad_target target;

  function automatic void compile_only();
    int inline_bad = target.randomize() with { soft (peer.cyc == 0); };
    int rooted_bad = std::randomize(target) with { soft (peer.cyc == 0); };
    int local_foreach_bad = target.randomize() with {
      foreach (values[k]) soft (values[k] == local::i);
    };
  endfunction
endclass

class randc_prov_bad_assoc_element;
  bit value;
endclass

class randc_prov_bad_assoc_key;
  randc bit cyc;
endclass

class randc_prov_bad_assoc_owner;
  randc_prov_bad_assoc_element q[randc_prov_bad_assoc_key];

  constraint class_key_iterator_bad {
    foreach (q[i]) soft (i.cyc == 0);
  }
endclass

module randc_prov_bad_let_scope;
  let read_cyc(value) = value.cyc;
  let read_specialized =
    randc_prov_bad_box#(randc_prov_bad_leaf)::obj.cyc;
  randc_prov_bad_leaf peer;
  randc_prov_bad_target target;

  function automatic void compile_only();
    int parameterized_let_bad = target.randomize() with {
      soft (read_cyc(peer) == 0);
    };
    int specialized_let_bad = target.randomize() with {
      soft (read_specialized == 0);
    };
  endfunction
endmodule

module test;
  randc_prov_bad_ast ast;
  randc_prov_bad_specialization specialization;
  randc_prov_bad_pkg::self_user self_user;
  randc_prov_bad_package_user package_user;
  randc_prov_bad_caller caller;
  randc_prov_bad_assoc_owner assoc_owner;
  randc_prov_bad_let_scope let_scope();

  initial begin
    caller = new;
    caller.target = new;
    caller.compile_only();
  end
endmodule
