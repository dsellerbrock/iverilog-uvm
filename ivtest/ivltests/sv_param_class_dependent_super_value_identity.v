// IEEE 1800-2017 8.25: each value-parameterized class specialization is a
// distinct type.  Substitution must continue through an inherited,
// parameterized superclass and its nested class-type actual.  Insert the
// default specialization first, then prove that the concrete specialization
// succeeds and a failed dynamic cast leaves its destination unchanged.
class df_root;
endclass

class df_seqr #(int WIDTH = 32) extends df_root;
  int width;
  function new;
    width = WIDTH;
  endfunction
endclass

class df_base #(type SEQR = df_seqr#(32));
  SEQR p_sequencer;
  function bit set_sequencer(df_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class df_mid #(int WIDTH = 32) extends df_base#(df_seqr#(WIDTH));
endclass

class df_leaf #(int WIDTH = 32) extends df_mid#(WIDTH);
endclass

class ub_root;
endclass

class ub_box #(int VALUE = 0) extends ub_root;
endclass

module sv_param_class_dependent_super_value_identity;
  parameter int UB = $;
  parameter int UB_ALIAS = UB;
  df_leaf#() df_default_first;
  df_leaf#(10) df_concrete_second;
  df_seqr#(10) df_good;
  df_seqr#(11) df_bad;
  ub_box#($) ub_direct;
  ub_box#(.VALUE($)) ub_named;
  ub_box#(UB) ub_alias;
  ub_box#(UB_ALIAS) ub_alias_chain;
  ub_box#(32'hxxxxxxxx) ordinary_all_x;
  initial begin
    bit df_ok;
    bit df_wrong;
    bit ub_named_ok;
    bit ub_direct_ok;
    bit ub_alias_ok;
    bit ordinary_all_x_wrong;
    ub_root candidate;

    df_default_first = new;
    df_concrete_second = new;
    df_good = new;
    df_bad = new;
    ub_direct = new;
    ub_named = new;
    ub_alias = new;
    ub_alias_chain = new;
    ordinary_all_x = new;

    df_ok = df_concrete_second.set_sequencer(df_good);
    df_wrong = df_concrete_second.set_sequencer(df_bad);

    candidate = ub_named;
    ub_named_ok = $cast(ub_direct, candidate);
    candidate = ub_alias;
    ub_direct_ok = $cast(ub_direct, candidate);
    candidate = ub_alias_chain;
    ub_alias_ok = $cast(ub_alias, candidate);
    candidate = ordinary_all_x;
    ordinary_all_x_wrong = $cast(ub_alias_chain, candidate);

    if (!df_ok || df_wrong ||
        df_concrete_second.p_sequencer == null ||
        df_concrete_second.p_sequencer.width != 10) begin
      $fatal(1, "default-first dependent superclass identity failed");
    end
    if (!ub_named_ok || !ub_direct_ok || !ub_alias_ok ||
        ordinary_all_x_wrong || !$isunbounded(UB) ||
        !$isunbounded(UB_ALIAS) || $isunbounded(32'hxxxxxxxx)) begin
      $fatal(1, "symbolic unbounded specialization identity failed");
    end
    $display("PASSED");
  end
endmodule
