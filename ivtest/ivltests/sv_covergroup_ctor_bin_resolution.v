// IEEE 1800-2017/2023 19.5.7: constructor-dependent bin values are
// resolved against the effective coverpoint type. Partly representable
// ranges are intersected with its domain; X/Z endpoints are excluded.
module top;
  covergroup cg_high(int high) with function sample(bit [2:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins high_clipped[] = {[6:high]};
    }
  endgroup

  covergroup cg_low(int low) with function sample(bit [2:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins low_clipped[] = {[low:2]};
    }
  endgroup

  covergroup cg_signed(int low, int high)
      with function sample(bit signed [2:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins signed_clipped[] = {[low:high]};
    }
  endgroup

  covergroup cg_ctor_source(bit signed [2:0] value, int low, int high);
    option.per_instance = 1;
    cp: coverpoint value {
      bins ctor_source_clipped = {[low:high]};
    }
  endgroup

  covergroup cg_ctor_select(bit [4:0] value, int high);
    option.per_instance = 1;
    cp: coverpoint value[2:0] {
      bins ctor_select_clipped = {[0:high]};
    }
  endgroup

  covergroup cg_x(logic [3:0] high)
      with function sample(bit [3:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins x_excluded[] = {[0:high]};
    }
  endgroup

  covergroup cg_z(logic [3:0] high)
      with function sample(bit [3:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins z_excluded[] = {[0:high]};
    }
  endgroup

  covergroup cg_unsigned_endpoint_to_signed(bit [2:0] bound)
      with function sample(bit signed [2:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins accepted = {bound};
    }
  endgroup

  covergroup cg_signed_endpoint_to_unsigned(bit signed [2:0] bound)
      with function sample(bit [2:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins excluded = {bound};
    }
  endgroup

  covergroup cg_mixed_signed_unsigned(bit signed [2:0] low,
                                      bit [2:0] high)
      with function sample(bit signed [2:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins retained[] = {[low:high]};
    }
  endgroup

  covergroup cg_mixed_unsigned_signed(bit [2:0] low,
                                      bit signed [2:0] high)
      with function sample(bit signed [2:0] value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins retained[] = {[low:high]};
    }
  endgroup

  class set_capture_c;
    int signed legal_values[$];
    bit signed [2:0] value;
    covergroup cg;
      option.per_instance = 1;
      cp: coverpoint value {
        bins captured_values[] = legal_values;
      }
    endgroup

    function new();
      legal_values.push_back(-2);
      legal_values.push_back(6);
      legal_values.push_back(-6);
      cg = new;
      // A set_covergroup_expression is captured when the covergroup is
      // constructed, not lazily at the first sample/query.
      legal_values[0] = 1;
    endfunction

    function void sample(bit signed [2:0] observed);
      value = observed;
      cg.sample();
    endfunction
  endclass

  class unsigned_set_to_signed_c;
    bit [2:0] legal_values[$];
    bit signed [2:0] value;
    covergroup cg;
      option.per_instance = 1;
      cp: coverpoint value {
        bins accepted[] = legal_values;
      }
    endgroup

    function new();
      legal_values.push_back(3'b110);
      cg = new;
    endfunction

    function void sample(bit signed [2:0] observed);
      value = observed;
      cg.sample();
    endfunction
  endclass

  class signed_set_to_unsigned_c;
    bit signed [2:0] illegal_values[$];
    bit [2:0] value;
    covergroup cg;
      option.per_instance = 1;
      cp: coverpoint value {
        bins excluded[] = illegal_values;
      }
    endgroup

    function new();
      illegal_values.push_back(-2);
      cg = new;
    endfunction

    function void sample(bit [2:0] observed);
      value = observed;
      cg.sample();
    endfunction
  endclass

  cg_high high_clip;
  cg_low low_clip;
  cg_signed signed_clip;
  cg_ctor_source ctor_source_clip;
  cg_ctor_select ctor_select_clip;
  cg_x x_endpoint;
  cg_z z_endpoint;
  cg_unsigned_endpoint_to_signed unsigned_endpoint_to_signed;
  cg_signed_endpoint_to_unsigned signed_endpoint_to_unsigned;
  cg_mixed_signed_unsigned mixed_signed_unsigned;
  cg_mixed_unsigned_signed mixed_unsigned_signed;
  set_capture_c set_capture;
  unsigned_set_to_signed_c unsigned_set_to_signed;
  signed_set_to_unsigned_c signed_set_to_unsigned;

  initial begin
    // [6:10] intersects the unsigned three-bit domain as [6:7].
    high_clip = new(10);
    high_clip.sample(6);
    if (high_clip.get_inst_coverage() != 50.0)
      $fatal(1, "high-clipped range did not create two bins");
    high_clip.sample(7);
    if (high_clip.get_inst_coverage() != 100.0)
      $fatal(1, "high-clipped range did not retain both valid values");

    // [-2:2] intersects that same domain as [0:2].
    low_clip = new(-2);
    low_clip.sample(0);
    if (low_clip.get_inst_coverage() < 33.0 ||
        low_clip.get_inst_coverage() > 34.0)
      $fatal(1, "negative-to-unsigned intersection did not create three bins");
    low_clip.sample(1);
    low_clip.sample(2);
    if (low_clip.get_inst_coverage() != 100.0)
      $fatal(1, "negative-to-unsigned intersection lost a valid value");

    // [-6:-2] intersects the signed three-bit domain as [-4:-2].
    signed_clip = new(-6, -2);
    signed_clip.sample(-4);
    if (signed_clip.get_inst_coverage() < 33.0 ||
        signed_clip.get_inst_coverage() > 34.0)
      $fatal(1, "signed-domain intersection did not create three bins");
    signed_clip.sample(-3);
    signed_clip.sample(-2);
    if (signed_clip.get_inst_coverage() != 100.0)
      $fatal(1, "signed-domain intersection lost a valid value");

    // A constructor formal is a lexical coverpoint source and shadows any
    // like-named parent property. Its declared signed three-bit type governs
    // endpoint resolution even for selected/composite sizing paths.
    ctor_source_clip = new(-2, -6, -2);
    ctor_source_clip.sample();
    if (ctor_source_clip.get_inst_coverage() != 100.0)
      $fatal(1, "constructor-formal coverpoint source lost its type");

    // Selected constructor-formal sources use the selected width rather than
    // falling back to the unbound identifier's default integer width.
    ctor_select_clip = new(5, 10);
    ctor_select_clip.sample();
    if (ctor_select_clip.get_inst_coverage() != 100.0)
      $fatal(1, "selected constructor-formal source lost its width");

    // Either X/Z endpoint excludes the complete range; it must not be
    // coerced to zero and must issue the required value-resolution warning.
    x_endpoint = new(4'bx001);
    x_endpoint.sample(0);
    if (x_endpoint.get_inst_coverage() != 0.0)
      $fatal(1, "X constructor endpoint was coerced into a bin value");
    z_endpoint = new(4'bz001);
    z_endpoint.sample(0);
    if (z_endpoint.get_inst_coverage() != 0.0)
      $fatal(1, "Z constructor endpoint was coerced into a bin value");

    // Static casting 3'b110 from an unsigned source to a signed three-bit
    // coverpoint produces -2, but normal == comparison is unsigned and the
    // identical bit pattern remains equal. It must therefore be retained.
    unsigned_endpoint_to_signed = new(3'b110);
    unsigned_endpoint_to_signed.sample(-2);
    if (unsigned_endpoint_to_signed.get_inst_coverage() != 100.0)
      $fatal(1, "unsigned endpoint bit pattern was lost on signed cast");

    // IEEE 1800 19.5.7 explicitly warns and excludes a signed negative
    // source converted to an unsigned coverpoint, despite the same bits.
    signed_endpoint_to_unsigned = new(-2);
    signed_endpoint_to_unsigned.sample(3'b110);
    if (signed_endpoint_to_unsigned.get_inst_coverage() != 0.0)
      $fatal(1, "signed negative endpoint survived an unsigned cast");

    // Resolve each mixed-sign endpoint independently. Both declarations
    // denote the effective signed range [-2:2], including the unsigned
    // 3'b110 low endpoint that casts to signed -2.
    mixed_signed_unsigned = new(-2, 2);
    mixed_signed_unsigned.sample(-2);
    if (mixed_signed_unsigned.get_inst_coverage() != 20.0)
      $fatal(1, "signed/unsigned endpoints lost the negative range");
    mixed_signed_unsigned.sample(-1);
    mixed_signed_unsigned.sample(0);
    mixed_signed_unsigned.sample(1);
    mixed_signed_unsigned.sample(2);
    if (mixed_signed_unsigned.get_inst_coverage() != 100.0)
      $fatal(1, "signed/unsigned endpoints did not retain [-2:2]");

    mixed_unsigned_signed = new(3'b110, 2);
    mixed_unsigned_signed.sample(-2);
    if (mixed_unsigned_signed.get_inst_coverage() != 20.0)
      $fatal(1, "unsigned/signed endpoints lost the cast low endpoint");
    mixed_unsigned_signed.sample(-1);
    mixed_unsigned_signed.sample(0);
    mixed_unsigned_signed.sample(1);
    mixed_unsigned_signed.sample(2);
    if (mixed_unsigned_signed.get_inst_coverage() != 100.0)
      $fatal(1, "unsigned/signed endpoints did not retain [-2:2]");

    // Signed set members are resolved against the signed coverpoint domain.
    // Out-of-domain singletons are excluded, while the surviving -2 is
    // encoded as the three-bit coverpoint value 3'b110. The mutation
    // after cg=new must not replace it with 1.
    set_capture = new;
    set_capture.sample(1);
    if (set_capture.cg.get_inst_coverage() != 0.0)
      $fatal(1, "parent set was captured lazily after construction");
    set_capture.sample(-2);
    if (set_capture.cg.get_inst_coverage() != 100.0)
      $fatal(1, "signed set element did not resolve into coverpoint domain");

    // Apply the same asymmetric signedness rules to set expressions.
    unsigned_set_to_signed = new;
    unsigned_set_to_signed.sample(-2);
    if (unsigned_set_to_signed.cg.get_inst_coverage() != 100.0)
      $fatal(1, "unsigned set bit pattern was lost on signed cast");
    signed_set_to_unsigned = new;
    signed_set_to_unsigned.sample(3'b110);
    if (signed_set_to_unsigned.cg.get_inst_coverage() != 0.0)
      $fatal(1, "signed negative set element survived an unsigned cast");

    $display("PASSED");
  end
endmodule
