// IEEE 1800-2017 8.25: each value-parameterized class specialization is a
// distinct type.  Substitution must continue through an inherited,
// parameterized superclass and its nested class-type actual.  Exercise both
// cache insertion orders and prove that a failed dynamic cast leaves the
// previously assigned destination unchanged.
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

class cf_root;
endclass

class cf_seqr #(int WIDTH = 32) extends cf_root;
  int width;
  function new;
    width = WIDTH;
  endfunction
endclass

class cf_base #(type SEQR = cf_seqr#(32));
  SEQR p_sequencer;
  function bit set_sequencer(cf_root sequencer);
    return $cast(p_sequencer, sequencer);
  endfunction
endclass

class cf_mid #(int WIDTH = 32) extends cf_base#(cf_seqr#(WIDTH));
endclass

class cf_leaf #(int WIDTH = 32) extends cf_mid#(WIDTH);
endclass

module sv_param_class_dependent_super_value_identity;
  df_leaf#() df_default_first;
  df_leaf#(10) df_concrete_second;
  df_seqr#(10) df_good;
  df_seqr#(11) df_bad;
  cf_leaf#(10) cf_concrete_first;
  cf_leaf#() cf_default_second;
  cf_seqr#(10) cf_good;
  cf_seqr#(11) cf_bad;

  initial begin
    bit df_ok;
    bit df_wrong;
    bit cf_ok;
    bit cf_wrong;

    df_default_first = new;
    df_concrete_second = new;
    df_good = new;
    df_bad = new;

    cf_concrete_first = new;
    cf_default_second = new;
    cf_good = new;
    cf_bad = new;

    df_ok = df_concrete_second.set_sequencer(df_good);
    df_wrong = df_concrete_second.set_sequencer(df_bad);
    cf_ok = cf_concrete_first.set_sequencer(cf_good);
    cf_wrong = cf_concrete_first.set_sequencer(cf_bad);

    if (!df_ok || df_wrong ||
        df_concrete_second.p_sequencer == null ||
        df_concrete_second.p_sequencer.width != 10) begin
      $fatal(1, "default-first dependent superclass identity failed");
    end
    if (!cf_ok || cf_wrong ||
        cf_concrete_first.p_sequencer == null ||
        cf_concrete_first.p_sequencer.width != 10) begin
      $fatal(1, "concrete-first dependent superclass identity failed");
    end

    $display("PASSED");
  end
endmodule
