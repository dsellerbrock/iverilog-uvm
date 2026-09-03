// IEEE 1800-2017/2023 6.20.2, 6.20.3, 13.5.3, and 25.8/25.9.
// Model the OpenTitan pins_if parameter/default shape: both effective value
// parameters, including the explicitly typed PullStrength parameter,
// participate in the complete virtual-interface type. The modport prototypes
// are a separate generic 25.7/25.9 control: default and explicit-default
// specializations are identical, while distinct selections remain distinct
// full types.
interface param_vif_pins_if #(
    parameter int WIDTH = 32,
    parameter bit [31:0] PullStrength = 32'h0102_0304
);
  logic [WIDTH-1:0] pins;
  bit [31:0] applied_pull;
  int call_count;

  // The implementation has no default. A named call through a modport that
  // supplies only value must therefore obtain PullStrength from that
  // specialization's full import prototype (IEEE 1800-2023 25.7).
  function void set_pins(
      input bit [31:0] strength,
      input logic [WIDTH-1:0] value);
    applied_pull = strength;
    pins = value;
    call_count += 1;
  endfunction

  // Deliberately differs from the drive prototype default below. Section
  // 25.7 requires a call through that modport to use the prototype default.
  function bit [31:0] add_pull(
      input bit [31:0] strength = 32'hdeaf_beef,
      input bit [31:0] value);
    return strength + value;
  endfunction

  modport drive(
      output pins,
      import function void set_pins(
          input bit [31:0] strength = PullStrength,
          input logic [WIDTH-1:0] value),
      import function bit [31:0] add_pull(
          input bit [31:0] strength = PullStrength,
          input bit [31:0] value));
  modport observe(
      input pins,
      import function void set_pins(
          input bit [31:0] strength = PullStrength,
          input logic [WIDTH-1:0] value));
endinterface

module sv_vif_parameter_specialization_pins;
  localparam bit [31:0] DEFAULT_PULL = 32'h0102_0304;
  localparam bit [31:0] ALT_PULL = 32'h5566_7788;

  param_vif_pins_if implicit_default();
  param_vif_pins_if #() empty_default();
  param_vif_pins_if #(
      .WIDTH(32), .PullStrength(DEFAULT_PULL)) explicit_default();
  param_vif_pins_if #(
      .WIDTH(32), .PullStrength(ALT_PULL)) alternate_pull();
  param_vif_pins_if #(
      .WIDTH(16), .PullStrength(DEFAULT_PULL)) narrow_width();
  param_vif_pins_if #(
      .WIDTH(32), .PullStrength(DEFAULT_PULL)) selected_views();

  virtual interface param_vif_pins_if implicit_vif;
  virtual interface param_vif_pins_if #() empty_vif;
  virtual interface param_vif_pins_if #(
      .WIDTH(32), .PullStrength(DEFAULT_PULL)) explicit_vif;
  virtual interface param_vif_pins_if #(
      .WIDTH(32), .PullStrength(ALT_PULL)) alternate_vif;
  virtual interface param_vif_pins_if #(
      .WIDTH(16), .PullStrength(DEFAULT_PULL)) narrow_vif;
  virtual interface param_vif_pins_if #(
      .WIDTH(32), .PullStrength(DEFAULT_PULL)).drive drive_vif;
  virtual interface param_vif_pins_if #(
      .WIDTH(32), .PullStrength(ALT_PULL)).drive alternate_drive_vif;
  // The observe view is used only as a distinct full VIF type; repeating the
  // full prototype also proves that each modport owns an independent formal
  // scope, despite the matching formal names.
  virtual interface param_vif_pins_if #(
      .WIDTH(32), .PullStrength(DEFAULT_PULL)).observe observe_vif;
  bit [31:0] prototype_result;
  bit [31:0] alternate_prototype_result;

  initial begin
    implicit_vif = implicit_default;
    empty_vif = empty_default;
    explicit_vif = explicit_default;
    alternate_vif = alternate_pull;
    narrow_vif = narrow_width;
    drive_vif = selected_views.drive;
    alternate_drive_vif = alternate_pull.drive;
    observe_vif = selected_views.observe;

    // type(vif) uses the exact complete VIF type, independent of the bound
    // instance. Equivalent effective defaults compare equal; either value
    // parameter and either modport name can make the full type distinct.
    if (type(implicit_vif) != type(empty_vif)
        || type(implicit_vif) != type(explicit_vif)
        || type(implicit_vif) == type(alternate_vif)
        || type(implicit_vif) == type(narrow_vif)
        || type(implicit_vif) == type(drive_vif)
        || type(drive_vif) == type(alternate_drive_vif)
        || type(drive_vif) == type(observe_vif))
      $fatal(1, "pins_if complete virtual-interface type identity failed");

    // Unqualified views use the implementation declaration and therefore
    // supply strength explicitly. Only the selected drive view exercises the
    // defaulted-first/required-second import prototype.
    implicit_vif.set_pins(
        .strength(DEFAULT_PULL), .value(32'ha5a5_5a5a));
    explicit_vif.set_pins(
        .strength(DEFAULT_PULL), .value(32'h1234_5678));
    alternate_vif.set_pins(
        .strength(ALT_PULL), .value(32'hcafe_f00d));
    narrow_vif.set_pins(
        .strength(DEFAULT_PULL), .value(16'hbeef));
    drive_vif.set_pins(.value(32'h0bad_c0de));
    prototype_result = drive_vif.add_pull(.value(32'h10));
    alternate_prototype_result =
        alternate_drive_vif.add_pull(.value(32'h20));

    if (implicit_default.pins !== 32'ha5a5_5a5a
        || implicit_default.applied_pull !== DEFAULT_PULL
        || explicit_default.pins !== 32'h1234_5678
        || explicit_default.applied_pull !== DEFAULT_PULL
        || alternate_pull.pins !== 32'hcafe_f00d
        || alternate_pull.applied_pull !== ALT_PULL
        || narrow_width.pins !== 16'hbeef
        || narrow_width.applied_pull !== DEFAULT_PULL
        || selected_views.pins !== 32'h0bad_c0de
        || selected_views.applied_pull !== DEFAULT_PULL
        || prototype_result !== DEFAULT_PULL + 32'h10
        || alternate_prototype_result !== ALT_PULL + 32'h20
        || implicit_default.call_count != 1
        || explicit_default.call_count != 1
        || alternate_pull.call_count != 1
        || narrow_width.call_count != 1
        || selected_views.call_count != 1)
      $fatal(1, "pins_if specialized default argument or dispatch failed");

    $display("PASSED");
  end
endmodule
