// IEEE 1800-2017/2023 6.20.2, 6.20.3, 8.25, and 25.9.
// A virtual-interface type used as a class type actual retains the complete
// effective interface specialization. In particular, equal aggregate widths
// do not make different unpacked-array parameter values, element types, or
// modport selections the same class specialization.
interface param_vif_cache_if #(
    parameter WIDTH = 8,
    parameter type ELEM_T = logic [WIDTH-1:0],
    parameter int SHAPE [0:1] = '{1, 4}
);
  ELEM_T data;
  logic [SHAPE[0]+SHAPE[1]-1:0] shape_data;
  modport observe(input data, shape_data);
endinterface

typedef virtual interface param_vif_cache_if #(
    .WIDTH(8), .ELEM_T(logic [7:0]), .SHAPE('{1, 4})) cache_a_vif_t;
typedef virtual interface param_vif_cache_if #(
    .WIDTH(8), .ELEM_T(logic [7:0]), .SHAPE('{2, 3})) cache_b_vif_t;
typedef virtual interface param_vif_cache_if #(
    .WIDTH(8), .ELEM_T(bit [7:0]), .SHAPE('{1, 4})) cache_bit_vif_t;
typedef virtual interface param_vif_cache_if #(
    .WIDTH(8), .ELEM_T(logic [7:0]), .SHAPE('{1, 4})).observe
    cache_a_observe_vif_t;

class param_vif_cache_box #(type VIF_T = cache_a_vif_t);
  VIF_T vif;

  function new(VIF_T value);
    vif = value;
  endfunction

  function int data_width();
    return $bits(vif.data);
  endfunction

  function int shape_width();
    return $bits(vif.shape_data);
  endfunction
endclass

module sv_vif_parameter_specialization_class_cache;
  param_vif_cache_if #(
      .WIDTH(8), .ELEM_T(logic [7:0]), .SHAPE('{1, 4})) a0();
  param_vif_cache_if #(
      .WIDTH(8), .ELEM_T(logic [7:0]), .SHAPE('{1, 4})) a1();
  param_vif_cache_if #(
      .WIDTH(8), .ELEM_T(logic [7:0]), .SHAPE('{2, 3})) b0();
  param_vif_cache_if #(
      .WIDTH(8), .ELEM_T(bit [7:0]), .SHAPE('{1, 4})) bit0();

  param_vif_cache_box #(cache_a_vif_t) box_a0;
  param_vif_cache_box #(cache_a_vif_t) box_a1;
  param_vif_cache_box #(cache_b_vif_t) box_b;
  param_vif_cache_box #(cache_bit_vif_t) box_bit;
  param_vif_cache_box #(cache_a_observe_vif_t) box_observe;

  initial begin
    box_a0 = new(a0);
    box_a1 = new(a1);
    box_b = new(b0);
    box_bit = new(bit0);
    box_observe = new(a0);

    if (type(box_a0) != type(box_a1)
        || type(box_a0) == type(box_b)
        || type(box_a0) == type(box_bit)
        || type(box_a0) == type(box_observe))
      $fatal(1, "virtual-interface class-specialization identity failed");

    box_a0.vif.data = 8'ha5;
    box_a0.vif.shape_data = 5'h13;
    box_b.vif.data = 8'h3c;
    box_b.vif.shape_data = 5'h0d;
    box_bit.vif.data = 8'h5a;

    if (a0.data !== 8'ha5 || a0.shape_data !== 5'h13
        || b0.data !== 8'h3c || b0.shape_data !== 5'h0d
        || bit0.data !== 8'h5a
        || box_a0.data_width() != 8 || box_b.data_width() != 8
        || box_a0.shape_width() != 5 || box_b.shape_width() != 5
        || box_observe.vif.data !== 8'ha5)
      $fatal(1, "virtual-interface class-specialization behavior failed");

    $display("PASSED");
  end
endmodule
