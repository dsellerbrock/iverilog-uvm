// IEEE 1800-2017/2023 6.20.2, 6.22.1, 8.25, and 25.9.
// Parameterized virtual-interface identity must use fully evaluated semantic
// types. This exercises two historically lossy seams together: a class
// specialization formed in a rootless interface declaration scope, and type
// parameters whose elaborated carriers used the generic debug_dump fallback.

interface cache_provenance_local_if #(parameter int N = 8);
  class C #(parameter int M = 1);
    logic [M-1:0] payload;
  endclass

  C #(N + 1) item;
endinterface

typedef logic [7:0] cache_fixed_lr_t [0:1];
typedef logic [7:0] cache_fixed_rl_t [1:0];

typedef struct {
  logic [3:0] lo;
  logic [3:0] hi;
} cache_struct_a_t;

typedef struct {
  logic [3:0] lo;
  logic [3:0] hi;
} cache_struct_b_t;

typedef logic [7:0] cache_queue_2_t[$:2];
typedef logic [7:0] cache_queue_4_t[$:4];
typedef bit   [7:0] cache_queue_bit_t[$:2];
typedef logic [7:0] cache_dynamic_logic_t[];
typedef bit   [7:0] cache_dynamic_bit_t[];
typedef integer cache_predefined_integer_t;
typedef logic signed [31:0] cache_explicit_integer_t;
typedef byte cache_predefined_byte_t;
typedef bit signed [7:0] cache_explicit_byte_t;

interface cache_provenance_type_if #(parameter type T = logic);
  T value;
endinterface

typedef virtual interface cache_provenance_local_if #(8)  cache_local8_vif_t;
typedef virtual interface cache_provenance_local_if #(16) cache_local16_vif_t;

typedef virtual interface cache_provenance_type_if #(cache_fixed_lr_t)
    cache_fixed_lr_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_fixed_rl_t)
    cache_fixed_rl_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_struct_a_t)
    cache_struct_a_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_struct_b_t)
    cache_struct_b_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_queue_2_t)
    cache_queue_2_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_queue_4_t)
    cache_queue_4_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_queue_bit_t)
    cache_queue_bit_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_dynamic_logic_t)
    cache_dynamic_logic_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_dynamic_bit_t)
    cache_dynamic_bit_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_predefined_integer_t)
    cache_predefined_integer_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_explicit_integer_t)
    cache_explicit_integer_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_predefined_byte_t)
    cache_predefined_byte_vif_t;
typedef virtual interface cache_provenance_type_if #(cache_explicit_byte_t)
    cache_explicit_byte_vif_t;

class cache_provenance_box #(type VIF_T);
  VIF_T vif;

  function new(VIF_T value);
    vif = value;
  endfunction
endclass

module sv_vif_parameter_specialization_cache_provenance;
  cache_provenance_local_if #(8)  local8_a();
  cache_provenance_local_if #(8)  local8_b();
  cache_provenance_local_if #(16) local16();

  cache_provenance_type_if #(cache_fixed_lr_t) fixed_lr();
  cache_provenance_type_if #(cache_fixed_lr_t) fixed_lr_same();
  cache_provenance_type_if #(cache_fixed_rl_t) fixed_rl();
  cache_provenance_type_if #(cache_struct_a_t) struct_a();
  cache_provenance_type_if #(cache_struct_b_t) struct_b();
  cache_provenance_type_if #(cache_queue_2_t) queue_2();
  cache_provenance_type_if #(cache_queue_4_t) queue_4();
  cache_provenance_type_if #(cache_queue_bit_t) queue_bit();
  cache_provenance_type_if #(cache_dynamic_logic_t) dynamic_logic();
  cache_provenance_type_if #(cache_dynamic_bit_t) dynamic_bit();
  cache_provenance_type_if #(cache_predefined_integer_t) predefined_integer();
  cache_provenance_type_if #(cache_explicit_integer_t) explicit_integer();
  cache_provenance_type_if #(cache_predefined_byte_t) predefined_byte();
  cache_provenance_type_if #(cache_explicit_byte_t) explicit_byte();

  cache_local8_vif_t local8_vif_a;
  cache_local8_vif_t local8_vif_b;
  cache_local16_vif_t local16_vif;

  cache_provenance_box #(cache_fixed_lr_vif_t) fixed_lr_box;
  cache_provenance_box #(cache_fixed_lr_vif_t) fixed_lr_same_box;
  cache_provenance_box #(cache_fixed_rl_vif_t) fixed_rl_box;
  cache_provenance_box #(cache_struct_a_vif_t) struct_a_box;
  cache_provenance_box #(cache_struct_b_vif_t) struct_b_box;
  cache_provenance_box #(cache_queue_2_vif_t) queue_2_box;
  cache_provenance_box #(cache_queue_4_vif_t) queue_4_box;
  cache_provenance_box #(cache_queue_bit_vif_t) queue_bit_box;
  cache_provenance_box #(cache_dynamic_logic_vif_t) dynamic_logic_box;
  cache_provenance_box #(cache_dynamic_bit_vif_t) dynamic_bit_box;
  cache_provenance_box #(cache_predefined_integer_vif_t)
      predefined_integer_box;
  cache_provenance_box #(cache_explicit_integer_vif_t)
      explicit_integer_box;
  cache_provenance_box #(cache_predefined_byte_vif_t) predefined_byte_box;
  cache_provenance_box #(cache_explicit_byte_vif_t) explicit_byte_box;

  initial begin
    local8_vif_a = local8_a;
    local8_vif_b = local8_b;
    local16_vif = local16;
    local8_a.item = new;
    local8_b.item = new;
    local16.item = new;

    fixed_lr_box = new(fixed_lr);
    fixed_lr_same_box = new(fixed_lr_same);
    fixed_rl_box = new(fixed_rl);
    struct_a_box = new(struct_a);
    struct_b_box = new(struct_b);
    queue_2_box = new(queue_2);
    queue_4_box = new(queue_4);
    queue_bit_box = new(queue_bit);
    dynamic_logic_box = new(dynamic_logic);
    dynamic_bit_box = new(dynamic_bit);
    predefined_integer_box = new(predefined_integer);
    explicit_integer_box = new(explicit_integer);
    predefined_byte_box = new(predefined_byte);
    explicit_byte_box = new(explicit_byte);

    if (type(fixed_lr_box) != type(fixed_lr_same_box)
        || type(fixed_lr_box) == type(fixed_rl_box)
        || type(struct_a_box) == type(struct_b_box)
        || type(queue_2_box) != type(queue_4_box)
        || type(queue_2_box) == type(queue_bit_box)
        || type(dynamic_logic_box) == type(dynamic_bit_box)
        || type(predefined_integer_box) != type(explicit_integer_box)
        || type(predefined_byte_box) != type(explicit_byte_box))
      $fatal(1, "interface type-parameter cache provenance failed");

    if ($bits(local8_a.item.payload) != 9
        || $bits(local16.item.payload) != 17)
      $fatal(1, "concrete dependent class specialization control failed");
    // A class declaration inside each physical interface instance has a
    // distinct nominal owner even when its evaluated parameters match (6.22).
    if (type(local8_a.item) == type(local8_b.item))
      $fatal(1, "physical interface-local class specializations aliased");
    // These are two expressions through the same declared VIF view. Their
    // static member type is the canonical rootless declaration carrier; this
    // intentionally does not compare the distinct nominal C declarations in
    // physical interface instances local8_a and local8_b (6.22 preamble).
    if (type(local8_vif_a.item) != type(local8_vif_b.item))
      $fatal(1, "identical VIF declaration-view specializations diverged");
    if (type(local8_a.item) == type(local8_vif_a.item)
        || type(local8_b.item) == type(local8_vif_b.item))
      $fatal(1, "physical and rootless VIF declaration owners aliased");
    if ($bits(local8_vif_a.item.payload) != 9)
      $fatal(1, "rootless C#(8+1) payload width was not 9");
    if ($bits(local16_vif.item.payload) != 17)
      $fatal(1, "rootless C#(16+1) payload width was not 17");
    if (type(local8_vif_a.item) == type(local16_vif.item))
      $fatal(1, "distinct rootless class specializations aliased");

    $display("PASSED");
  end
endmodule
