// IEEE 1800-2017 8.25: value-parameterized class specializations are
// distinct types.  These two real values round to the same text at the
// default ostream precision, so a specialization key must retain their
// exact binary values while substituting the dependent superclass.
class rpc_root;
endclass

class rpc_seqr #(real VALUE = 1.0 + 1e-7) extends rpc_root;
  real value;
  function new;
    value = VALUE;
  endfunction
endclass

class rpc_base #(type SEQR = rpc_seqr#(1.0 + 1e-7));
  SEQR p_sequencer;
  function bit set_sequencer(rpc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class rpc_mid #(real VALUE = 1.0 + 1e-7)
    extends rpc_base#(rpc_seqr#(VALUE));
endclass

class rpc_leaf #(real VALUE = 1.0 + 1e-7) extends rpc_mid#(VALUE);
endclass

// The integral subexpression must retain integral division semantics before
// conversion to the real formal; 3/2 denotes 1.0 here, not 1.5.
class dpc_root;
endclass

class dpc_seqr #(real VALUE = 1.0) extends dpc_root;
  real value;
  function new;
    value = VALUE;
  endfunction
endclass

class dpc_base #(type SEQR = dpc_seqr#(1.0));
  SEQR p_sequencer;
  function bit set_sequencer(dpc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class dpc_mid #(real VALUE = 1.0) extends dpc_base#(dpc_seqr#(VALUE));
endclass

class dpc_leaf #(real VALUE = 1.0) extends dpc_mid#(VALUE);
endclass

// Adjacent controls pin exact four-state and raw string values through the
// same dependent-superclass path.
class ipc_root;
endclass

class ipc_seqr #(logic [3:0] VALUE = 4'b10xz) extends ipc_root;
  logic [3:0] value;
  function new;
    value = VALUE;
  endfunction
endclass

class ipc_base #(type SEQR = ipc_seqr#(4'b10xz));
  SEQR p_sequencer;
  function bit set_sequencer(ipc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class ipc_mid #(logic [3:0] VALUE = 4'b10xz)
    extends ipc_base#(ipc_seqr#(VALUE));
endclass

class ipc_leaf #(logic [3:0] VALUE = 4'b10xz) extends ipc_mid#(VALUE);
endclass

class spc_root;
endclass

class spc_seqr #(string VALUE = "left,=:") extends spc_root;
  string value;
  function new;
    value = VALUE;
  endfunction
endclass

class spc_base #(type SEQR = spc_seqr#("left,=:"));
  SEQR p_sequencer;
  function bit set_sequencer(spc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class spc_mid #(string VALUE = "left,=:")
    extends spc_base#(spc_seqr#(VALUE));
endclass

class spc_leaf #(string VALUE = "left,=:") extends spc_mid#(VALUE);
endclass

// A fully literal assignment pattern and the same typed value forwarded
// through two class parameters denote one unpacked-struct specialization.
typedef struct {
  int value;
} apc_value_t;

class apc_root;
endclass

class apc_seqr #(apc_value_t VALUE = '{1}) extends apc_root;
  apc_value_t value;
  function new;
    value = VALUE;
  endfunction
endclass

class apc_base #(type SEQR = apc_seqr#('{1}));
  SEQR p_sequencer;
  function bit set_sequencer(apc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class apc_mid #(apc_value_t VALUE = '{1})
    extends apc_base#(apc_seqr#(VALUE));
endclass

class apc_leaf #(apc_value_t VALUE = '{1}) extends apc_mid#(VALUE);
endclass

// A wider unsigned operand makes the common arithmetic expression unsigned
// before assignment to real.  The signed 8'hff operand therefore zero-extends
// and the effective value is 255.0.
class mpc_root;
endclass

class mpc_seqr #(real VALUE = 255.0) extends mpc_root;
endclass

class mpc_base #(type SEQR = mpc_seqr#(255.0));
  SEQR p_sequencer;
  function bit set_sequencer(mpc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class mpc_mid #(real VALUE = 255.0) extends mpc_base#(mpc_seqr#(VALUE));
endclass

class mpc_leaf #(real VALUE = 255.0) extends mpc_mid#(VALUE);
endclass

// Assignment to a two-state formal coerces every X/Z bit to zero before the
// value participates in class-specialization identity.
class bpc_root;
endclass

class bpc_seqr #(bit [3:0] VALUE = 0) extends bpc_root;
endclass

class bpc_base #(type SEQR = bpc_seqr#(0));
  SEQR p_sequencer;
  function bit set_sequencer(bpc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class bpc_mid #(bit [3:0] VALUE = 0) extends bpc_base#(bpc_seqr#(VALUE));
endclass

class bpc_leaf #(bit [3:0] VALUE = 0) extends bpc_mid#(VALUE);
endclass

// A selected packed parameter contributes the selected element, never the
// value of the whole parameter, to the specialization key.
class slc_root;
endclass

class slc_seqr #(int VALUE = 0) extends slc_root;
endclass

class slc_base #(type SEQR = slc_seqr#(0));
  SEQR p_sequencer;
  function bit set_sequencer(slc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class slc_mid #(int VALUE = 0) extends slc_base#(slc_seqr#(VALUE));
endclass

class slc_leaf #(int VALUE = 0) extends slc_mid#(VALUE);
endclass

// Constant compound forwarding is evaluated with the same SV width/sign
// rules as a direct specialization.
class cpc_root;
endclass

class cpc_seqr #(int VALUE = 0) extends cpc_root;
endclass

class cpc_base #(type SEQR = cpc_seqr#(0));
  SEQR p_sequencer;
  function bit set_sequencer(cpc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class cpc_mid #(int N = 0) extends cpc_base#(cpc_seqr#(N + 1));
endclass

class cpc_leaf #(int N = 0) extends cpc_mid#(N);
endclass

// Packed value-parameter assignment context reaches every supported
// arithmetic operand.  This keeps intermediate carry/sign information that
// would be lost if the expression were evaluated at its source width and
// widened only after the arithmetic.
class auc_root;
endclass

class auc_seqr #(logic [15:0] VALUE = 0) extends auc_root;
  logic [15:0] value;
  function new;
    value = VALUE;
  endfunction
endclass

class auc_base #(type SEQR = auc_seqr#(0));
  SEQR p_sequencer;
  function bit set_sequencer(auc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class auc_mid #(logic [15:0] VALUE = 0)
    extends auc_base#(auc_seqr#(VALUE));
endclass

class auc_leaf #(logic [15:0] VALUE = 0) extends auc_mid#(VALUE);
endclass

class asc_root;
endclass

class asc_seqr #(logic signed [15:0] VALUE = 0) extends asc_root;
  logic signed [15:0] value;
  function new;
    value = VALUE;
  endfunction
endclass

class asc_base #(type SEQR = asc_seqr#(0));
  SEQR p_sequencer;
  function bit set_sequencer(asc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class asc_mid #(logic signed [15:0] VALUE = 0)
    extends asc_base#(asc_seqr#(VALUE));
endclass

class asc_leaf #(logic signed [15:0] VALUE = 0) extends asc_mid#(VALUE);
endclass

package agc_pkg;
  typedef struct {
    int value;
  } simple_t;
  localparam simple_t SIMPLE_ONE = '{1};

  typedef struct {
    bit [3:0] flags;
    int values [0:1];
    string label;
  } nested_t;
  localparam nested_t NESTED_ONE =
      '{4'bx1z0, '{8'shff, 16'h0002}, "tag"};
endpackage

class agc_root;
endclass

class agc_seqr #(agc_pkg::simple_t VALUE = '{1}) extends agc_root;
endclass

class agc_base #(type SEQR = agc_seqr#('{1}));
  SEQR p_sequencer;
  function bit set_sequencer(agc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class agc_mid #(agc_pkg::simple_t VALUE = '{1})
    extends agc_base#(agc_seqr#(VALUE));
endclass

class agc_leaf #(agc_pkg::simple_t VALUE = '{1}) extends agc_mid#(VALUE);
endclass

class ngc_root;
endclass

class ngc_seqr #(
  agc_pkg::nested_t VALUE = '{4'b0100, '{-1, 2}, "tag"}
) extends ngc_root;
endclass

class ngc_base #(
  type SEQR = ngc_seqr#('{4'b0100, '{-1, 2}, "tag"})
);
  SEQR p_sequencer;
  function bit set_sequencer(ngc_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class ngc_mid #(
  agc_pkg::nested_t VALUE = '{4'b0100, '{-1, 2}, "tag"}
) extends ngc_base#(ngc_seqr#(VALUE));
endclass

class ngc_leaf #(
  agc_pkg::nested_t VALUE = '{4'b0100, '{-1, 2}, "tag"}
) extends ngc_mid#(VALUE);
endclass

module sv_param_class_dependent_super_real_identity;
  localparam logic [3:0] SELECT_SOURCE = 4'b0010;
  rpc_leaf#() default_first;
  rpc_leaf#(1.0 + 2e-7) close_second;
  rpc_seqr#(1.0 + 2e-7) good;
  rpc_seqr#(1.0 + 1e-7) wrong;
  rpc_leaf#(1.0000002) literal_second;
  rpc_seqr#(1.0000002) literal_good;
  rpc_seqr#(1.0000001) literal_wrong;
  dpc_leaf#(3/2) integral_division;
  dpc_seqr#(3/2) integral_division_good;
  dpc_seqr#(1.5) integral_division_wrong;
  dpc_leaf#(8'hff + 8'h01) integral_overflow;
  dpc_seqr#(0.0) integral_overflow_good;
  dpc_seqr#(256.0) integral_overflow_wrong;
  dpc_leaf#(-8'sd2) integral_unary;
  dpc_seqr#(-2.0) integral_unary_good;
  dpc_seqr#(254.0) integral_unary_wrong;
  ipc_leaf#() integral_default_first;
  ipc_leaf#(4'b10zx) integral_second;
  ipc_seqr#(4'b10zx) integral_good;
  ipc_seqr#(4'b10xz) integral_wrong;
  spc_leaf#() string_default_first;
  spc_leaf#("right,=:") string_second;
  spc_seqr#("right,=:") string_good;
  spc_seqr#("left,=:") string_wrong;
  apc_leaf#('{1}) aggregate_leaf;
  apc_seqr#('{1}) aggregate_good;
  apc_seqr#('{2}) aggregate_wrong;
  mpc_leaf#(8'shff + 16'h0000) mixed_sign_leaf;
  mpc_seqr#(.VALUE(255.0)) mixed_sign_good;
  mpc_seqr#(65535.0) mixed_sign_wrong;
  mpc_leaf#(-0.0) negative_zero_leaf;
  mpc_seqr#(-0.0) negative_zero_good;
  mpc_seqr#(0.0) negative_zero_wrong;
  mpc_leaf#(0.0/0.0) nan_leaf;
  mpc_seqr#(0.0/0.0) nan_good;
  mpc_seqr#(0.0) nan_wrong;
  bpc_leaf#(.VALUE(4'bxxxx)) two_state_leaf;
  bpc_seqr#(0) two_state_good;
  bpc_seqr#(.VALUE(4'bzzzz)) two_state_named_alias;
  bpc_seqr#(1) two_state_wrong;
  slc_leaf#(SELECT_SOURCE[1]) selected_leaf;
  slc_seqr#(1) selected_good;
  slc_seqr#(.VALUE(SELECT_SOURCE[1])) selected_named_alias;
  slc_seqr#(SELECT_SOURCE) selected_whole_wrong;
  cpc_leaf#(.N(3)) compound_leaf;
  cpc_seqr#(4) compound_good;
  cpc_seqr#(.VALUE(3 + 1)) compound_named_alias;
  cpc_seqr#(3) compound_wrong;
  auc_leaf#(8'hff + 8'h01) assignment_unsigned_leaf;
  auc_seqr#(16'd256) assignment_unsigned_good;
  auc_seqr#(16'd0) assignment_unsigned_wrong;
  asc_leaf#(8'sh7f + 8'sh01) assignment_signed_leaf;
  asc_leaf#(-8'sh80) assignment_unary_leaf;
  asc_leaf#((8'sh7f + 8'sh01) + 16'sd0) assignment_nested_leaf;
  asc_seqr#(16'sd128) assignment_signed_good;
  asc_seqr#(-16'sd128) assignment_signed_wrong;
  agc_leaf#() aggregate_default_leaf;
  agc_leaf#('{1}) aggregate_direct_leaf;
  agc_leaf#(agc_pkg::SIMPLE_ONE) aggregate_package_leaf;
  agc_seqr#('{1}) aggregate_direct_good;
  agc_seqr#(.VALUE(agc_pkg::SIMPLE_ONE)) aggregate_package_good;
  agc_seqr#('{2}) aggregate_value_wrong;
  ngc_leaf#() nested_default_leaf;
  ngc_leaf#('{4'bx1z0, '{8'shff, 16'h0002}, "tag"})
      nested_direct_leaf;
  ngc_leaf#(agc_pkg::NESTED_ONE) nested_package_leaf;
  ngc_seqr#('{4'b0100, '{-1, 2}, "tag"}) nested_direct_good;
  ngc_seqr#(.VALUE(agc_pkg::NESTED_ONE)) nested_package_good;
  ngc_seqr#('{4'b0100, '{-1, 2}, "other"}) nested_value_wrong;

  initial begin
    bit good_ok;
    bit wrong_ok;
    bit literal_good_ok;
    bit literal_wrong_ok;
    bit integral_division_good_ok;
    bit integral_division_wrong_ok;
    bit integral_overflow_good_ok;
    bit integral_overflow_wrong_ok;
    bit integral_unary_good_ok;
    bit integral_unary_wrong_ok;
    bit integral_good_ok;
    bit integral_wrong_ok;
    bit string_good_ok;
    bit string_wrong_ok;
    bit aggregate_good_ok;
    bit aggregate_wrong_ok;
    bit mixed_sign_good_ok;
    bit mixed_sign_wrong_ok;
    bit negative_zero_good_ok;
    bit negative_zero_wrong_ok;
    bit nan_good_ok;
    bit nan_wrong_ok;
    bit two_state_good_ok;
    bit two_state_alias_ok;
    bit two_state_wrong_ok;
    bit selected_good_ok;
    bit selected_alias_ok;
    bit selected_wrong_ok;
    bit compound_good_ok;
    bit compound_alias_ok;
    bit compound_wrong_ok;
    bit assignment_unsigned_good_ok;
    bit assignment_unsigned_wrong_ok;
    bit assignment_signed_good_ok;
    bit assignment_signed_wrong_ok;
    bit assignment_unary_good_ok;
    bit assignment_unary_wrong_ok;
    bit assignment_nested_good_ok;
    bit assignment_nested_wrong_ok;
    bit aggregate_default_ok;
    bit aggregate_direct_ok;
    bit aggregate_package_ok;
    bit aggregate_package_alias_ok;
    bit aggregate_value_wrong_ok;
    bit nested_default_ok;
    bit nested_direct_ok;
    bit nested_package_ok;
    bit nested_package_alias_ok;
    bit nested_value_wrong_ok;

    default_first = new;
    close_second = new;
    good = new;
    wrong = new;
    literal_second = new;
    literal_good = new;
    literal_wrong = new;
    integral_division = new;
    integral_division_good = new;
    integral_division_wrong = new;
    integral_overflow = new;
    integral_overflow_good = new;
    integral_overflow_wrong = new;
    integral_unary = new;
    integral_unary_good = new;
    integral_unary_wrong = new;
    integral_default_first = new;
    integral_second = new;
    integral_good = new;
    integral_wrong = new;
    string_default_first = new;
    string_second = new;
    string_good = new;
    string_wrong = new;
    aggregate_leaf = new;
    aggregate_good = new;
    aggregate_wrong = new;
    mixed_sign_leaf = new;
    mixed_sign_good = new;
    mixed_sign_wrong = new;
    negative_zero_leaf = new;
    negative_zero_good = new;
    negative_zero_wrong = new;
    nan_leaf = new;
    nan_good = new;
    nan_wrong = new;
    two_state_leaf = new;
    two_state_good = new;
    two_state_named_alias = new;
    two_state_wrong = new;
    selected_leaf = new;
    selected_good = new;
    selected_named_alias = new;
    selected_whole_wrong = new;
    compound_leaf = new;
    compound_good = new;
    compound_named_alias = new;
    compound_wrong = new;
    assignment_unsigned_leaf = new;
    assignment_unsigned_good = new;
    assignment_unsigned_wrong = new;
    assignment_signed_leaf = new;
    assignment_unary_leaf = new;
    assignment_nested_leaf = new;
    assignment_signed_good = new;
    assignment_signed_wrong = new;
    aggregate_default_leaf = new;
    aggregate_direct_leaf = new;
    aggregate_package_leaf = new;
    aggregate_direct_good = new;
    aggregate_package_good = new;
    aggregate_value_wrong = new;
    nested_default_leaf = new;
    nested_direct_leaf = new;
    nested_package_leaf = new;
    nested_direct_good = new;
    nested_package_good = new;
    nested_value_wrong = new;

    good_ok = close_second.set_sequencer(good);
    wrong_ok = close_second.set_sequencer(wrong);
    literal_good_ok = literal_second.set_sequencer(literal_good);
    literal_wrong_ok = literal_second.set_sequencer(literal_wrong);
    integral_division_good_ok =
        integral_division.set_sequencer(integral_division_good);
    integral_division_wrong_ok =
        integral_division.set_sequencer(integral_division_wrong);
    integral_overflow_good_ok =
        integral_overflow.set_sequencer(integral_overflow_good);
    integral_overflow_wrong_ok =
        integral_overflow.set_sequencer(integral_overflow_wrong);
    integral_unary_good_ok =
        integral_unary.set_sequencer(integral_unary_good);
    integral_unary_wrong_ok =
        integral_unary.set_sequencer(integral_unary_wrong);
    integral_good_ok = integral_second.set_sequencer(integral_good);
    integral_wrong_ok = integral_second.set_sequencer(integral_wrong);
    string_good_ok = string_second.set_sequencer(string_good);
    string_wrong_ok = string_second.set_sequencer(string_wrong);
    aggregate_good_ok = aggregate_leaf.set_sequencer(aggregate_good);
    aggregate_wrong_ok = aggregate_leaf.set_sequencer(aggregate_wrong);
    mixed_sign_good_ok = mixed_sign_leaf.set_sequencer(mixed_sign_good);
    mixed_sign_wrong_ok = mixed_sign_leaf.set_sequencer(mixed_sign_wrong);
    negative_zero_good_ok =
        negative_zero_leaf.set_sequencer(negative_zero_good);
    negative_zero_wrong_ok =
        negative_zero_leaf.set_sequencer(negative_zero_wrong);
    nan_good_ok = nan_leaf.set_sequencer(nan_good);
    nan_wrong_ok = nan_leaf.set_sequencer(nan_wrong);
    two_state_good_ok = two_state_leaf.set_sequencer(two_state_good);
    two_state_alias_ok =
        two_state_leaf.set_sequencer(two_state_named_alias);
    two_state_wrong_ok = two_state_leaf.set_sequencer(two_state_wrong);
    selected_good_ok = selected_leaf.set_sequencer(selected_good);
    selected_alias_ok = selected_leaf.set_sequencer(selected_named_alias);
    selected_wrong_ok = selected_leaf.set_sequencer(selected_whole_wrong);
    compound_good_ok = compound_leaf.set_sequencer(compound_good);
    compound_alias_ok = compound_leaf.set_sequencer(compound_named_alias);
    compound_wrong_ok = compound_leaf.set_sequencer(compound_wrong);
    assignment_unsigned_good_ok =
        assignment_unsigned_leaf.set_sequencer(assignment_unsigned_good);
    assignment_unsigned_wrong_ok =
        assignment_unsigned_leaf.set_sequencer(assignment_unsigned_wrong);
    assignment_signed_good_ok =
        assignment_signed_leaf.set_sequencer(assignment_signed_good);
    assignment_signed_wrong_ok =
        assignment_signed_leaf.set_sequencer(assignment_signed_wrong);
    assignment_unary_good_ok =
        assignment_unary_leaf.set_sequencer(assignment_signed_good);
    assignment_unary_wrong_ok =
        assignment_unary_leaf.set_sequencer(assignment_signed_wrong);
    assignment_nested_good_ok =
        assignment_nested_leaf.set_sequencer(assignment_signed_good);
    assignment_nested_wrong_ok =
        assignment_nested_leaf.set_sequencer(assignment_signed_wrong);
    aggregate_default_ok =
        aggregate_default_leaf.set_sequencer(aggregate_direct_good);
    aggregate_direct_ok =
        aggregate_direct_leaf.set_sequencer(aggregate_package_good);
    aggregate_package_ok =
        aggregate_package_leaf.set_sequencer(aggregate_direct_good);
    aggregate_package_alias_ok =
        aggregate_package_leaf.set_sequencer(aggregate_package_good);
    aggregate_value_wrong_ok =
        aggregate_package_leaf.set_sequencer(aggregate_value_wrong);
    nested_default_ok = nested_default_leaf.set_sequencer(nested_direct_good);
    nested_direct_ok = nested_direct_leaf.set_sequencer(nested_package_good);
    nested_package_ok = nested_package_leaf.set_sequencer(nested_direct_good);
    nested_package_alias_ok =
        nested_package_leaf.set_sequencer(nested_package_good);
    nested_value_wrong_ok =
        nested_package_leaf.set_sequencer(nested_value_wrong);
    if (!good_ok || wrong_ok || close_second.p_sequencer == null ||
        close_second.p_sequencer.value != (1.0 + 2e-7)) begin
      $fatal(1, "dependent real specialization identity failed");
    end
    if (!literal_good_ok || literal_wrong_ok ||
        literal_second.p_sequencer == null ||
        literal_second.p_sequencer.value != 1.0000002) begin
      $fatal(1, "direct real literal specialization identity failed");
    end
    if (!integral_division_good_ok || integral_division_wrong_ok ||
        integral_division.p_sequencer == null ||
        integral_division.p_sequencer.value != 1.0) begin
      $fatal(1, "integral-to-real specialization identity failed");
    end
    if (!integral_overflow_good_ok || integral_overflow_wrong_ok ||
        integral_overflow.p_sequencer == null ||
        integral_overflow.p_sequencer.value != 0.0) begin
      $fatal(1, "integral-overflow-to-real specialization identity failed");
    end
    if (!integral_unary_good_ok || integral_unary_wrong_ok ||
        integral_unary.p_sequencer == null ||
        integral_unary.p_sequencer.value != -2.0) begin
      $fatal(1, "integral-unary-to-real specialization identity failed");
    end
    if (!integral_good_ok || integral_wrong_ok ||
        integral_second.p_sequencer == null ||
        integral_second.p_sequencer.value !== 4'b10zx) begin
      $fatal(1, "dependent four-state specialization identity failed");
    end
    if (!string_good_ok || string_wrong_ok ||
        string_second.p_sequencer == null ||
        string_second.p_sequencer.value != "right,=:") begin
      $fatal(1, "dependent string specialization identity failed");
    end
    if (!aggregate_good_ok || aggregate_wrong_ok ||
        aggregate_leaf.p_sequencer == null ||
        aggregate_leaf.p_sequencer.value.value != 1) begin
      $fatal(1, "dependent aggregate specialization identity failed");
    end
    if (!mixed_sign_good_ok || mixed_sign_wrong_ok) begin
      $fatal(1, "mixed-sign integral-to-real specialization identity failed");
    end
    if (!negative_zero_good_ok || negative_zero_wrong_ok) begin
      $fatal(1, "negative-zero real specialization identity failed");
    end
    if (!nan_good_ok || nan_wrong_ok) begin
      $fatal(1, "NaN real specialization identity failed");
    end
    if (!two_state_good_ok || !two_state_alias_ok || two_state_wrong_ok) begin
      $fatal(1, "two-state formal specialization identity failed");
    end
    if (!selected_good_ok || !selected_alias_ok || selected_wrong_ok) begin
      $fatal(1, "selected parameter specialization identity failed");
    end
    if (!compound_good_ok || !compound_alias_ok || compound_wrong_ok) begin
      $fatal(1, "compound forwarded specialization identity failed");
    end
    if (!assignment_unsigned_good_ok || assignment_unsigned_wrong_ok ||
        assignment_unsigned_leaf.p_sequencer == null ||
        assignment_unsigned_leaf.p_sequencer.value != 16'd256) begin
      $fatal(1, "unsigned assignment-context specialization identity failed");
    end
    if (!assignment_signed_good_ok || assignment_signed_wrong_ok ||
        assignment_signed_leaf.p_sequencer == null ||
        assignment_signed_leaf.p_sequencer.value != 16'sd128) begin
      $fatal(1, "signed assignment-context specialization identity failed");
    end
    if (!assignment_unary_good_ok || assignment_unary_wrong_ok ||
        assignment_unary_leaf.p_sequencer == null ||
        assignment_unary_leaf.p_sequencer.value != 16'sd128) begin
      $fatal(1, "unary assignment-context specialization identity failed");
    end
    if (!assignment_nested_good_ok || assignment_nested_wrong_ok ||
        assignment_nested_leaf.p_sequencer == null ||
        assignment_nested_leaf.p_sequencer.value != 16'sd128) begin
      $fatal(1, "nested assignment-context specialization identity failed");
    end
    if (!aggregate_default_ok || !aggregate_direct_ok ||
        !aggregate_package_ok || !aggregate_package_alias_ok ||
        aggregate_value_wrong_ok) begin
      $fatal(1, "equal aggregate specialization identity failed");
    end
    if (!nested_default_ok || !nested_direct_ok || !nested_package_ok ||
        !nested_package_alias_ok || nested_value_wrong_ok) begin
      $fatal(1, "nested aggregate specialization identity failed");
    end

    $display("PASSED");
  end
endmodule
