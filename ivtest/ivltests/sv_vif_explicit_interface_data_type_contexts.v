// IEEE 1800-2017/2023 25.9 and Syntax 25-3: the optional `interface'
// keyword is part of the virtual-interface data_type.  Exercise that type
// directly and through typedefs in legal declaration contexts.  This test
// deliberately uses an unparameterized interface; parameter-specialization
// identity and assignment compatibility are a separate, still-open 25.9
// semantic requirement.
interface sv_vif_explicit_context_if;
  logic [7:0] data;
  modport observe(input data);
endinterface

typedef virtual interface sv_vif_explicit_context_if
    sv_vif_explicit_context_t;
typedef virtual interface sv_vif_explicit_context_if.observe
    sv_vif_explicit_observe_t;

virtual interface sv_vif_explicit_context_if
    sv_vif_explicit_context_unit_vif;
sv_vif_explicit_context_t sv_vif_explicit_context_unit_alias_vif;

package sv_vif_explicit_context_pkg;
  typedef virtual interface sv_vif_explicit_context_if
      sv_vif_explicit_context_package_t;
  virtual interface sv_vif_explicit_context_if package_vif;
  sv_vif_explicit_context_package_t package_alias_vif;
endpackage

typedef struct {
  virtual interface sv_vif_explicit_context_if direct_vif;
  sv_vif_explicit_context_t alias_vif;
} sv_vif_explicit_context_struct_t;

class sv_vif_explicit_context_holder;
  local virtual interface sv_vif_explicit_context_if local_vif;
  protected virtual interface sv_vif_explicit_context_if protected_vif;
  static virtual interface sv_vif_explicit_context_if static_vif;
  local static virtual interface sv_vif_explicit_context_if local_static_vif;
  protected static virtual interface sv_vif_explicit_context_if
      protected_static_vif;
  sv_vif_explicit_context_t alias_vif;
  sv_vif_explicit_observe_t observe_vif;

  function new(virtual interface sv_vif_explicit_context_if source);
    local_vif = source;
    protected_vif = source;
    alias_vif = source;
    observe_vif = source;
  endfunction

  static function void bind_static(
      virtual interface sv_vif_explicit_context_if source);
    static_vif = source;
    local_static_vif = source;
    protected_static_vif = source;
  endfunction

  function virtual interface sv_vif_explicit_context_if get_local();
    return local_vif;
  endfunction

  function bit [6:0] data_mask(input logic [7:0] expected);
    return {local_vif.data == expected, protected_vif.data == expected,
            static_vif.data == expected, local_static_vif.data == expected,
            protected_static_vif.data == expected, alias_vif.data == expected,
            observe_vif.data == expected};
  endfunction

  // Parser controls beside the qualified VIF properties: `virtual' also
  // introduces methods, so both qualifier orders must remain unambiguous.
  local virtual function int local_virtual_method_control();
    return 11;
  endfunction

  protected virtual function int protected_virtual_method_control();
    return 22;
  endfunction

  static function int static_method_control();
    return 33;
  endfunction

  function bit method_controls_pass();
    return local_virtual_method_control() == 11
        && protected_virtual_method_control() == 22
        && static_method_control() == 33;
  endfunction
endclass

class sv_vif_explicit_context_derived
    extends sv_vif_explicit_context_holder;
  function new(virtual interface sv_vif_explicit_context_if source);
    super.new(source);
  endfunction

  function virtual interface sv_vif_explicit_context_if get_protected();
    return protected_vif;
  endfunction
endclass

function automatic virtual interface sv_vif_explicit_context_if
    sv_vif_explicit_context_identity(
        input sv_vif_explicit_context_t source);
  return source;
endfunction

task automatic sv_vif_explicit_context_copy(
    input virtual interface sv_vif_explicit_context_if source,
    output sv_vif_explicit_context_t destination);
  destination = source;
endtask

module sv_vif_explicit_interface_data_type_contexts;
  import sv_vif_explicit_context_pkg::*;

  sv_vif_explicit_context_if bus();
  virtual interface sv_vif_explicit_context_if module_vif;
  sv_vif_explicit_context_t module_alias_vif;
  sv_vif_explicit_context_struct_t aggregate;
  sv_vif_explicit_context_derived holder;
  int checks;

  initial begin : legal_block_context
    automatic virtual interface sv_vif_explicit_context_if block_vif = bus;
    automatic sv_vif_explicit_context_t block_alias_vif;

    block_alias_vif = block_vif;
    module_vif = sv_vif_explicit_context_identity(block_alias_vif);
    sv_vif_explicit_context_copy(module_vif, module_alias_vif);

    sv_vif_explicit_context_unit_vif = bus;
    sv_vif_explicit_context_unit_alias_vif = bus;
    package_vif = bus;
    package_alias_vif = bus;
    aggregate.direct_vif = bus;
    aggregate.alias_vif = bus;

    holder = new(bus);
    sv_vif_explicit_context_holder::bind_static(bus);

    bus.data = 8'h5a;
    block_vif = holder.get_local();
    block_alias_vif = holder.get_protected();
    if (module_vif.data !== 8'h5a)
      $fatal(1, "direct module-scope VIF lost identity");
    if (module_alias_vif.data !== 8'h5a)
      $fatal(1, "typedef module-scope VIF lost identity");
    if (module_vif != module_alias_vif)
      $fatal(1, "legal virtual-interface equality comparison failed");
    if (sv_vif_explicit_context_unit_vif.data !== 8'h5a)
      $fatal(1, "direct compilation-unit VIF lost identity");
    if (sv_vif_explicit_context_unit_alias_vif.data !== 8'h5a)
      $fatal(1, "typedef compilation-unit VIF lost identity");
    if (package_vif.data !== 8'h5a)
      $fatal(1, "direct package VIF lost identity");
    if (package_alias_vif.data !== 8'h5a)
      $fatal(1, "typedef package VIF lost identity");
    if (aggregate.direct_vif.data !== 8'h5a)
      $fatal(1, "direct unpacked-struct VIF member lost identity");
    if (aggregate.alias_vif.data !== 8'h5a)
      $fatal(1, "typedef unpacked-struct VIF member lost identity");
    if (block_vif.data !== 8'h5a)
      $fatal(1, "direct block/function-return VIF lost identity");
    if (block_alias_vif.data !== 8'h5a)
      $fatal(1, "typedef block/function-return VIF lost identity");
    if (holder.data_mask(8'h5a) !== 7'h7f)
      $fatal(1, "qualified class VIF property mask=%07b expected=1111111",
             holder.data_mask(8'h5a));
    if (!holder.method_controls_pass())
      $fatal(1, "class method parser control failed at runtime");

    // Syntax 12-5 admits the 25.9 data_type in a declaring for-loop.
    for (virtual interface sv_vif_explicit_context_if loop_vif = bus;
         loop_vif != null; loop_vif = null)
      checks++;

    if (checks != 1)
      $fatal(1, "declaring-for virtual-interface variable misbehaved");

    $display("PASSED");
  end
endmodule
