// IEEE 1800-2017/2023 6.20.2, 6.20.3, 6.22.3, and 25.9.
// Virtual-interface assignment compatibility includes effective parameter
// values and types and the selected modport. The sole modport relaxation is
// an unselected source assigned to a selected-modport destination.
interface param_vif_assign_if #(
    parameter WIDTH = 8,
    parameter TAG = 0,
    parameter type PAYLOAD_T = logic [WIDTH-1:0]
);
  PAYLOAD_T data;
  modport phy(input data);
endinterface

module sv_vif_parameter_specialization_assignment_fail;
  param_vif_assign_if #(16) p16();
  param_vif_assign_if #(32) p32();
  param_vif_assign_if #(.WIDTH(16), .TAG(8'd3)) p_tag8();
  param_vif_assign_if #(.WIDTH(16), .TAG(16'd3)) p_tag16();
  param_vif_assign_if #(.WIDTH(16), .PAYLOAD_T(bit [15:0])) p_bit16();
  param_vif_assign_if #(
      .WIDTH(16), .PAYLOAD_T(logic [15:0])) p_logic16();

  virtual interface param_vif_assign_if #(16) v16;
  virtual interface param_vif_assign_if #(32) v32;
  virtual interface param_vif_assign_if #(
      .WIDTH(16), .TAG(16'd3)) v_tag16;
  virtual interface param_vif_assign_if #(
      .WIDTH(16), .PAYLOAD_T(logic [15:0])) v_logic16;
  virtual interface param_vif_assign_if #(16).phy v16_phy;
  virtual interface param_vif_assign_if #(32).phy v32_phy;

  initial begin
    // Legal controls: same specialization and the one-way modport relaxation.
    v16 = p16;
    v32 = p32;
    v16_phy = v16;
    v32_phy = p32;
    v16_phy = p16.phy;
    v_tag16 = p_tag16;
    v_logic16 = p_logic16;

    // Parameter-value specialization mismatch: concrete and VIF sources.
    v16 = p32;
    v16 = v32;

    // Equal numeric TAG values still have different inferred parameter types.
    v_tag16 = p_tag8;

    // Type-parameter actuals are part of the specialization identity.
    v_logic16 = p_bit16;

    // A selected-modport source cannot flow back to an unqualified destination.
    v16 = v16_phy;
    v32 = p32.phy;
  end
endmodule
