`begin_keywords "1800-2012"

// Packed concatenation l-values may combine class/interface properties with
// ordinary variables. Exercise whole properties, null receivers, both mixed
// orders, and constant packed-field selects while keeping the expected slice
// order visible in the literals below.
interface concat_object_lvalue_if;
  typedef struct packed {
    logic [1:0] upper;
    logic [2:0] lower;
  } fields_t;

  logic [2:0] whole;
  fields_t fields;
endinterface

class concat_object_lvalue_c;
  logic [1:0] upper;
  logic [2:0] lower;
endclass

module sv_concat_object_lvalue_shapes;
  concat_object_lvalue_if intf();
  virtual concat_object_lvalue_if vif;
  concat_object_lvalue_c obj;
  logic [1:0] ordinary;
  logic [3:0] after_null;

  initial begin
    vif = intf;
    obj = new;

    // Two whole class properties. The rightmost property is l-value zero
    // internally and therefore receives the least-significant three bits.
    {obj.upper, obj.lower} = 5'b10_110;
    if ({obj.upper, obj.lower} !== 5'b10_110)
      $fatal(1, "whole class properties: upper=%b lower=%b",
             obj.upper, obj.lower);

    // Every null receiver must discard exactly its own slice. A following
    // vector store and then another object assignment detect either stack
    // underflow or a leaked vec4/object value.
    obj = null;
    {obj.upper, obj.lower} = 5'b01_001;
    after_null = 4'ha;
    obj = new;
    {obj.upper, obj.lower} = 5'b11_100;
    if (after_null !== 4'ha ||
        {obj.upper, obj.lower} !== 5'b11_100)
      $fatal(1, "null receiver stack balance: after=%h upper=%b lower=%b",
             after_null, obj.upper, obj.lower);

    // A packed concatenation can place the ordinary l-value on either side
    // of a direct virtual-interface property.
    {ordinary, vif.whole} = 5'b11_001;
    if (ordinary !== 2'b11 || vif.whole !== 3'b001)
      $fatal(1, "mixed ordinary/property: ordinary=%b whole=%b",
             ordinary, vif.whole);

    {vif.whole, ordinary} = 5'b101_10;
    if (vif.whole !== 3'b101 || ordinary !== 2'b10)
      $fatal(1, "mixed property/ordinary: whole=%b ordinary=%b",
             vif.whole, ordinary);

    // Constant packed-field offsets require two independent RMW stores into
    // the same interface property; neither store may clobber the other field.
    vif.fields = 'x;
    {vif.fields.upper, vif.fields.lower} = 5'b01_101;
    if (vif.fields !== 5'b01_101)
      $fatal(1, "constant packed fields: fields=%b", vif.fields);

    $display("PASSED");
  end
endmodule

`end_keywords
