module sv_ustruct_member_defaults;
  localparam integer DEFAULT_SERIAL = 7;
  integer failures = 0;

  class marker;
  endclass

  typedef struct {
    string text = "member-default";
    real ratio = 1.25;
    marker handle = null;
  } nonintegral_t;

  typedef struct {
    logic [3:0] untouched;
    integer serial = DEFAULT_SERIAL;
    integer payload = 9;
  } record_t;
  typedef record_t record_alias_t;
  typedef record_alias_t record_alias2_t;

  typedef struct {
    integer left = 11;
    integer right = 12;
  } plain_leaf_t;
  typedef struct {
    plain_leaf_t leaf;
    integer tail = 13;
  } plain_outer_t;

  // The whole initializer suppresses defaults for only this declarator.
  record_t first, overridden = '{4'h5, 100, 200}, second;
  record_alias2_t aliased;
  plain_outer_t nested_value;
  nonintegral_t nonintegral_value;
  const plain_leaf_t const_whole_value = '{31, 32};

  class defaults_holder;
    plain_outer_t value;
    static plain_outer_t static_value;
    plain_leaf_t overridden_value = '{21, 22};
    const plain_leaf_t const_whole_value = '{31, 32};

    function integer values_ok;
      values_ok = value.leaf.left == 11 && value.leaf.right == 12 &&
                  value.tail == 13 && overridden_value.left == 21 &&
                  overridden_value.right == 22 &&
                  const_whole_value.left == 31 &&
                  const_whole_value.right == 32;
    endfunction

    static function integer static_values_ok;
      static_values_ok = static_value.leaf.left == 11 &&
                         static_value.leaf.right == 12 &&
                         static_value.tail == 13;
    endfunction
  endclass

  defaults_holder holder;

  task automatic exercise_auto(input logic [3:0] poison);
    record_alias_t left, right;
    begin
      if (left.untouched !== 4'bxxxx || left.serial !== DEFAULT_SERIAL ||
          left.payload !== 9 || right.untouched !== 4'bxxxx ||
          right.serial !== DEFAULT_SERIAL || right.payload !== 9) begin
        $display("FAILED automatic defaults");
        failures = failures + 1;
      end

      // A later invocation must initialize fresh automatic instances.
      left.untouched = poison;
      left.serial = poison;
      left.payload = poison;
      right.untouched = poison;
      right.serial = poison;
      right.payload = poison;
    end
  endtask

  initial begin
    if (first.untouched !== 4'bxxxx ||
        first.serial !== DEFAULT_SERIAL || first.payload !== 9 ||
        second.untouched !== 4'bxxxx ||
        second.serial !== DEFAULT_SERIAL || second.payload !== 9 ||
        aliased.untouched !== 4'bxxxx ||
        aliased.serial !== DEFAULT_SERIAL || aliased.payload !== 9) begin
      $display("FAILED static defaults or implicit-X preservation");
      failures = failures + 1;
    end

    if (overridden.untouched !== 4'h5 || overridden.serial !== 100 ||
        overridden.payload !== 200) begin
      $display("FAILED whole initializer suppression");
      failures = failures + 1;
    end

    if (nested_value.leaf.left !== 11 ||
        nested_value.leaf.right !== 12 || nested_value.tail !== 13) begin
      $display("FAILED nested scalar defaults: {%0d,%0d,%0d}",
               nested_value.leaf.left, nested_value.leaf.right,
               nested_value.tail);
      failures = failures + 1;
    end
    if (nonintegral_value.text != "member-default" ||
        nonintegral_value.ratio != 1.25 ||
        nonintegral_value.handle != null) begin
      $display("FAILED non-integral constant defaults");
      failures = failures + 1;
    end
    if (const_whole_value.left !== 31 ||
        const_whole_value.right !== 32) begin
      $display("FAILED const whole initializer suppression: {%0d,%0d}",
               const_whole_value.left, const_whole_value.right);
      failures = failures + 1;
    end

    holder = new;
    if (!holder.values_ok()) begin
      $display("FAILED class property defaults");
      failures = failures + 1;
    end
    if (!defaults_holder::static_values_ok()) begin
      $display("FAILED static class property defaults");
      failures = failures + 1;
    end

    exercise_auto(4'h6);
    exercise_auto(4'h9);

    if (failures == 0)
      $display("PASSED");
    else
      $display("FAILED (%0d errors)", failures);
    $finish(0);
  end
endmodule
