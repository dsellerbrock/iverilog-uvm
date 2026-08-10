// Positive controls for the IEEE 1800-2017 randc restrictions on soft,
// solve-before, uniqueness, and distribution constraints.  These cases make
// sure qualifier provenance does not leak through a shadowed iterator or a
// statically selected plain specialization, while package and type scoped
// functions remain distinct from object-member method calls.
typedef enum bit [1:0] {
  RANDC_PROV_A = 2'd0,
  RANDC_PROV_B = 2'd1,
  RANDC_PROV_C = 2'd2
} randc_prov_e;

class randc_prov_plain_leaf;
  randc_prov_e e;
  bit [1:0] x;
  bit [1:0] cyc;

  function randc_prov_plain_leaf id();
    return this;
  endfunction
endclass

class randc_prov_cycle_leaf;
  randc randc_prov_e e;
  randc bit [1:0] x;
  randc bit [1:0] cyc;

  function randc_prov_cycle_leaf id();
    return this;
  endfunction
endclass

package randc_prov_pkg;
  typedef enum bit [1:0] {
    RANDC_PROV_PKG_A = 2'd0,
    RANDC_PROV_PKG_B = 2'd1
  } enum_t;

  class leaf;
    enum_t e;
  endclass

  leaf obj;

  function automatic int f();
    return 1;
  endfunction
endpackage

class randc_prov_type;
  static function automatic int f();
    return 1;
  endfunction
endclass

class randc_prov_box #(type T = randc_prov_cycle_leaf);
  static T obj;
endclass

class randc_prov_static_box;
  static randc_prov_plain_leaf q[2][2];
endclass

class randc_prov_name_controls;
  // The package object's name deliberately collides with an object property.
  randc bit obj;

  constraint package_enum_method_ok {
    soft (randc_prov_pkg::obj.e.next() == randc_prov_pkg::RANDC_PROV_PKG_A);
  }
  constraint scoped_function_ok { soft (randc_prov_type::f() == 1); }
  constraint package_function_ok { soft (randc_prov_pkg::f() == 1); }
endclass

class randc_prov_iterator_controls;
  // Same-named randc properties must lose to the typed iterator declarations.
  randc bit [1:0] i;
  randc bit [1:0] j;
  randc bit [1:0] item;
  rand bit [1:0] values[2][2];
  rand randc_prov_plain_leaf q2[2][2];
  rand randc_prov_plain_leaf q3[2][2][2];

  constraint foreach_shadow_ok {
    foreach (values[i,j]) soft (i == 0);
  }
  constraint default_iterator_shadow_ok {
    soft (values[0].sum() with (item) >= 0);
  }
  constraint nested_iterator_ok {
    soft ((q2.find() with
      ((item.find(j) with (j.x == 0)).size() > 0)).size() == 0);
  }
  constraint selected_nested_iterator_ok {
    soft ((q3[0].find(i) with
      ((i.find(j) with (j.x == 0)).size() > 0)).size() == 0);
  }
  constraint scoped_static_partial_ok {
    soft ((randc_prov_static_box::q[0].find(item) with
      (item.x == 0)).size() == 0);
  }
  constraint selected_outer_iterator_ok {
    soft ((q2.find() with (item[0].id().cyc == 0)).size() == 0);
  }
endclass

class randc_prov_assoc_element;
  bit value;
endclass

class randc_prov_assoc_plain_key;
  bit cyc;
endclass

class randc_prov_assoc_shadow;
  randc bit cyc;
endclass

class randc_prov_assoc_iterator_control;
  randc_prov_assoc_element q[randc_prov_assoc_plain_key];
  // The foreach key iterator shadows this same-named class property.
  randc_prov_assoc_shadow i;

  constraint class_key_shadow_ok {
    foreach (q[i]) soft (i.cyc == 0);
  }
endclass

class randc_prov_locator_iterator_control;
  rand randc_prov_plain_leaf q[2];
  // The second find() iterator shadows this randc-bearing property.
  rand randc_prov_cycle_leaf j;

  constraint chained_locator_shadow_ok {
    soft (((q.find(i) with (1)).find(j) with
      (j.cyc == 0)).size() == 0);
  }
endclass

class randc_prov_base;
  bit [1:0] cyc;
endclass

class randc_prov_derived extends randc_prov_base;
  randc bit [1:0] cyc;
endclass

class randc_prov_specialization_controls;
  rand bit pick;
  rand randc_prov_derived derived_obj;
  rand randc_prov_base base_obj;

  constraint static_specialization_ok {
    soft (randc_prov_box#(randc_prov_plain_leaf)::obj.id().cyc == 0);
  }
  constraint ternary_base_type_ok {
    soft ((pick ? derived_obj : base_obj).cyc == 0);
  }
endclass

class randc_prov_inline_target;
  rand bit x;
endclass

module randc_prov_let_control;
  let read_plain = randc_prov_box#(randc_prov_plain_leaf)::obj.cyc;
  randc_prov_inline_target target;

  function automatic void compile_only();
    int ignored = target.randomize() with { soft (read_plain == 0); };
  endfunction
endmodule

module test;
  randc_prov_name_controls names;
  randc_prov_iterator_controls iterators;
  randc_prov_assoc_iterator_control assoc_iterator;
  randc_prov_locator_iterator_control locator_iterator;
  randc_prov_specialization_controls specializations;

  initial begin
    names = new;
    iterators = new;
    assoc_iterator = new;
    locator_iterator = new;
    specializations = new;
    $display("PASSED");
  end
endmodule
