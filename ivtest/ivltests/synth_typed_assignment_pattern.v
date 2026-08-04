`begin_keywords "1800-2012"

package p;
  typedef struct packed {
    logic [7:0] hi;
    logic [7:0] lo;
  } cfg_t;
  typedef struct packed {
    logic [7:0] lo;
    logic [7:0] hi;
  } override_cfg_t;
  typedef struct {
    logic [7:0] hi;
    logic [7:0] lo;
  } unpacked_cfg_t;
  typedef struct {
    logic [7:0] lo;
    logic [7:0] hi;
  } unpacked_override_cfg_t;
  typedef logic [7:0] byte_pair_t [0:1];
  typedef logic [7:0] byte_darray_t [];
  typedef logic [7:0] byte_queue_t [$];
endpackage

class scoped_pattern_types;
  typedef p::cfg_t typedef_t;
  localparam type parameter_t = p::override_cfg_t;
endclass

module typed_parameter_pattern #(
  parameter type T = p::cfg_t
) (
  input  logic [7:0]  hi,
  input  logic [7:0]  lo,
  output logic [31:0] value
);
  // A type parameter is registered as a type identifier in this scope and
  // must remain the target context for its assignment pattern.
  assign value = {2{T'{lo: lo, hi: hi}}};
endmodule

module typed_nonpacked_parameter_pattern #(
  parameter type        T  = p::unpacked_cfg_t,
  parameter logic [7:0] HI = 8'hbb,
  parameter logic [7:0] LO = 8'h44
) (
  output logic [15:0] value
);
  T shaped;

  // This direct nonpacked T'{...} path deliberately has no enclosing
  // concatenation to width-test the cast first. Each specialization must
  // therefore resolve T in its own instance scope rather than reusing a
  // parse-expression cache populated by an earlier instance.
  (* ivl_synthesis_off *) initial begin
    shaped = T'{lo: LO, hi: HI};
    value = {shaped.hi, shaped.lo};
  end
endmodule

module synth_typed_assignment_pattern;
  typedef p::cfg_t cfg_alias_t;

  // The names are deliberately reversed from their declaration order. The
  // typed literal must still be a 16-bit cfg_t before concatenation
  // replication, producing BB44 twice rather than replicating a one-bit or
  // otherwise context-sized assignment-pattern placeholder.
  logic [7:0] scoped_hi;
  logic [7:0] scoped_lo;
  logic [7:0] alias_hi;
  logic [7:0] alias_lo;
  logic [31:0] scoped_value;
  logic [31:0] alias_value;
  logic [31:0] class_typedef_value;
  logic [31:0] class_parameter_value;
  logic        atom_fill;
  logic [31:0] atom_value;
  logic [15:0] type_ref_source;
  logic [15:0] type_ref_value;
  logic [31:0] parameter_default_value;
  logic [31:0] parameter_override_value;
  logic [15:0] nonpacked_parameter_default_value;
  logic [15:0] nonpacked_parameter_override_value;
  p::byte_pair_t unpacked_value;
  p::byte_darray_t dynamic_value;
  p::byte_queue_t queue_value;

  assign scoped_value =
      {2{p::cfg_t'{lo: scoped_lo, hi: scoped_hi}}};
  assign alias_value =
      {2{cfg_alias_t'{lo: alias_lo, hi: alias_hi}}};
  assign class_typedef_value =
      {2{scoped_pattern_types::typedef_t'{lo: alias_lo, hi: alias_hi}}};
  assign class_parameter_value =
      {2{scoped_pattern_types::parameter_t'{hi: scoped_hi, lo: scoped_lo}}};
  assign atom_value = int'{default: atom_fill};
  assign type_ref_value = type(type_ref_source)'{default: atom_fill};

  typed_parameter_pattern parameter_default (
    .hi(scoped_hi),
    .lo(scoped_lo),
    .value(parameter_default_value)
  );

  typed_parameter_pattern #(
    .T(p::override_cfg_t)
  ) parameter_override (
    .hi(alias_hi),
    .lo(alias_lo),
    .value(parameter_override_value)
  );

  typed_nonpacked_parameter_pattern nonpacked_parameter_default (
    .value(nonpacked_parameter_default_value)
  );

  typed_nonpacked_parameter_pattern #(
    .T(p::unpacked_override_cfg_t),
    .HI(8'ha5),
    .LO(8'h3c)
  ) nonpacked_parameter_override (
    .value(nonpacked_parameter_override_value)
  );

  // A non-packed typed pattern is already fully shaped by its target type;
  // it must not fall through the scalar cast fallback after elaboration.
  always_comb unpacked_value = p::byte_pair_t'{scoped_hi, scoped_lo};

  (* ivl_synthesis_off *)
  initial begin
    scoped_hi = 8'hbb;
    scoped_lo = 8'h44;
    alias_hi = 8'ha5;
    alias_lo = 8'h3c;
    atom_fill = 1'b1;
    type_ref_source = 16'h1234;
    dynamic_value = p::byte_darray_t'{scoped_hi, scoped_lo};
    queue_value = p::byte_queue_t'{alias_hi, alias_lo};
    #1;
    if (scoped_value[31:24] !== 8'hbb ||
        scoped_value[23:16] !== 8'h44 ||
        scoped_value[15:8]  !== 8'hbb ||
        scoped_value[7:0]   !== 8'h44) begin
      $display("FAILED -- scoped typed pattern = %h", scoped_value);
      $finish;
    end
    if (alias_value !== 32'ha53c_a53c) begin
      $display("FAILED -- alias typed pattern = %h", alias_value);
      $finish;
    end
    if (class_typedef_value !== 32'ha53c_a53c) begin
      $display("FAILED -- class-scoped typedef pattern = %h",
               class_typedef_value);
      $finish;
    end
    // parameter_t resolves to override_cfg_t, whose declaration order is
    // lo then hi. This distinguishes its class-scoped type context from the
    // surrounding 32-bit replication result.
    if (class_parameter_value !== 32'h44bb_44bb) begin
      $display("FAILED -- class-scoped type-parameter pattern = %h",
               class_parameter_value);
      $finish;
    end
    if (unpacked_value[0] !== 8'hbb || unpacked_value[1] !== 8'h44) begin
      $display("FAILED -- unpacked typed pattern = %h/%h",
               unpacked_value[0], unpacked_value[1]);
      $finish;
    end
    if (atom_value !== 32'hffff_ffff) begin
      $display("FAILED -- int typed pattern = %h", atom_value);
      $finish;
    end
    if (type_ref_value !== 16'hffff) begin
      $display("FAILED -- type-reference pattern = %h", type_ref_value);
      $finish;
    end
    if (parameter_default_value !== 32'hbb44_bb44) begin
      $display("FAILED -- default type-parameter pattern = %h",
               parameter_default_value);
      $finish;
    end
    // The override declares lo before hi, proving the overridden T supplies
    // the packed member order instead of silently retaining the default type.
    if (parameter_override_value !== 32'h3ca5_3ca5) begin
      $display("FAILED -- overridden type-parameter pattern = %h",
               parameter_override_value);
      $finish;
    end
    if (nonpacked_parameter_default_value !== 16'hbb44) begin
      $display("FAILED -- default nonpacked type-parameter pattern = %h",
               nonpacked_parameter_default_value);
      $finish;
    end
    if (nonpacked_parameter_override_value !== 16'ha53c) begin
      $display("FAILED -- overridden nonpacked type-parameter pattern = %h",
               nonpacked_parameter_override_value);
      $finish;
    end
    if (dynamic_value.size() != 2 || dynamic_value[0] !== 8'hbb ||
        dynamic_value[1] !== 8'h44) begin
      $display("FAILED -- dynamic typed pattern size/value = %0d %h/%h",
               dynamic_value.size(), dynamic_value[0], dynamic_value[1]);
      $finish;
    end
    if (queue_value.size() != 2 || queue_value[0] !== 8'ha5 ||
        queue_value[1] !== 8'h3c) begin
      $display("FAILED -- queue typed pattern size/value = %0d %h/%h",
               queue_value.size(), queue_value[0], queue_value[1]);
      $finish;
    end

    scoped_hi = 8'h12;
    scoped_lo = 8'he7;
    alias_hi = 8'hc6;
    alias_lo = 8'h09;
    atom_fill = 1'b0;
    type_ref_source = 16'habcd;
    dynamic_value = p::byte_darray_t'{scoped_hi, scoped_lo};
    queue_value = p::byte_queue_t'{alias_hi, alias_lo};
    #1;
    if (scoped_value !== 32'h12e7_12e7) begin
      $display("FAILED -- updated scoped typed pattern = %h", scoped_value);
      $finish;
    end
    if (alias_value !== 32'hc609_c609) begin
      $display("FAILED -- updated alias typed pattern = %h", alias_value);
      $finish;
    end
    if (class_typedef_value !== 32'hc609_c609) begin
      $display("FAILED -- updated class-scoped typedef pattern = %h",
               class_typedef_value);
      $finish;
    end
    if (class_parameter_value !== 32'he712_e712) begin
      $display("FAILED -- updated class-scoped type-parameter pattern = %h",
               class_parameter_value);
      $finish;
    end
    if (unpacked_value[0] !== 8'h12 || unpacked_value[1] !== 8'he7) begin
      $display("FAILED -- updated unpacked typed pattern = %h/%h",
               unpacked_value[0], unpacked_value[1]);
      $finish;
    end
    if (atom_value !== 32'h0000_0000) begin
      $display("FAILED -- updated int typed pattern = %h", atom_value);
      $finish;
    end
    if (type_ref_value !== 16'h0000) begin
      $display("FAILED -- updated type-reference pattern = %h", type_ref_value);
      $finish;
    end
    if (parameter_default_value !== 32'h12e7_12e7) begin
      $display("FAILED -- updated default type-parameter pattern = %h",
               parameter_default_value);
      $finish;
    end
    if (parameter_override_value !== 32'h09c6_09c6) begin
      $display("FAILED -- updated overridden type-parameter pattern = %h",
               parameter_override_value);
      $finish;
    end
    if (dynamic_value.size() != 2 || dynamic_value[0] !== 8'h12 ||
        dynamic_value[1] !== 8'he7) begin
      $display("FAILED -- updated dynamic typed pattern = %0d %h/%h",
               dynamic_value.size(), dynamic_value[0], dynamic_value[1]);
      $finish;
    end
    if (queue_value.size() != 2 || queue_value[0] !== 8'hc6 ||
        queue_value[1] !== 8'h09) begin
      $display("FAILED -- updated queue typed pattern = %0d %h/%h",
               queue_value.size(), queue_value[0], queue_value[1]);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
