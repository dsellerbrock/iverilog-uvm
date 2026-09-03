// IEEE 1800-2017/2023 6.20.2, 6.22.1, 8.25, and 25.9. Every repeated I#(1)
// elaboration after the first creates a temporary parameter scope that is
// discarded on the semantic cache hit. The following I#(99) deliberately
// reuses that allocator size class. A specialization key must serialize the
// live NetExpr value, never reuse a cached key indexed by its former address.
class allocator_reuse_item #(parameter int WIDTH = 1);
  bit [WIDTH-1:0] payload;
endclass

interface allocator_reuse_if #(
  parameter int WIDTH = 1,
  parameter type ITEM_T = allocator_reuse_item #(WIDTH)
);
  ITEM_T item;
endinterface

module sv_vif_parameter_specialization_allocator_reuse;
  allocator_reuse_if #(99) physical();

  virtual allocator_reuse_if #(1) scratch_00;
  virtual allocator_reuse_if #(1) scratch_01;
  virtual allocator_reuse_if #(1) scratch_02;
  virtual allocator_reuse_if #(1) scratch_03;
  virtual allocator_reuse_if #(1) scratch_04;
  virtual allocator_reuse_if #(1) scratch_05;
  virtual allocator_reuse_if #(1) scratch_06;
  virtual allocator_reuse_if #(1) scratch_07;
  virtual allocator_reuse_if #(1) scratch_08;
  virtual allocator_reuse_if #(1) scratch_09;
  virtual allocator_reuse_if #(1) scratch_10;
  virtual allocator_reuse_if #(1) scratch_11;
  virtual allocator_reuse_if #(1) scratch_12;
  virtual allocator_reuse_if #(1) scratch_13;
  virtual allocator_reuse_if #(1) scratch_14;
  virtual allocator_reuse_if #(1) scratch_15;
  virtual allocator_reuse_if #(1) scratch_16;
  virtual allocator_reuse_if #(1) scratch_17;
  virtual allocator_reuse_if #(1) scratch_18;
  virtual allocator_reuse_if #(1) scratch_19;
  virtual allocator_reuse_if #(1) scratch_20;
  virtual allocator_reuse_if #(1) scratch_21;
  virtual allocator_reuse_if #(1) scratch_22;
  virtual allocator_reuse_if #(1) scratch_23;

  // Keep the victim immediately after the cache-hit churn so a freed
  // constant-expression slot is the allocator's next reuse candidate.
  virtual allocator_reuse_if #(99) victim;

  initial begin
    victim = physical;
    physical.item = new;
    if ($bits(victim.item.payload) != 99)
      $fatal(1, "discarded expression poisoned I#(99) specialization");
    if (type(victim.item) == type(scratch_23.item))
      $fatal(1, "I#(99) class actual aliased cached I#(1) actual");
    $display("PASSED");
  end
endmodule
