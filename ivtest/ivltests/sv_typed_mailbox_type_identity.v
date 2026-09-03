// IEEE 1800-2017/2023 6.22.1 and 15.4.9: a concrete mailbox type actual is
// retained in specialization identity. Matching actual types share one type,
// distinct actual types do not, and the untyped default remains dynamic.
typedef bit signed [31:0] mailbox_matching_int_t;

class mailbox_nominal_message;
  int payload;
endclass

class mailbox_distinct_message;
  int payload;
endclass

typedef mailbox_nominal_message mailbox_nominal_message_alias_t;

module sv_typed_mailbox_type_identity;
  mailbox #(int) mbx_int;
  mailbox #(mailbox_matching_int_t) mbx_matching_alias;
  mailbox #(string) mbx_string;
  mailbox #(mailbox_nominal_message) mbx_nominal;
  mailbox #(mailbox_nominal_message_alias_t) mbx_nominal_alias;
  mailbox #(mailbox_distinct_message) mbx_distinct;
  mailbox mbx_untyped;
  mailbox #() mbx_explicit_default;

  int int_value;
  int int_result;
  string string_value;
  string string_result;
  mailbox_nominal_message_alias_t nominal_value;
  mailbox_nominal_message nominal_result;

  initial begin
    if (type(mbx_int) != type(mbx_matching_alias))
      $fatal(1, "matching mailbox actual types did not intern together");
    if (type(mbx_int) == type(mbx_string))
      $fatal(1, "distinct mailbox actual types aliased");
    if (type(mbx_nominal) != type(mbx_nominal_alias))
      $fatal(1, "a class and its typedef alias did not intern together");
    if (type(mbx_nominal) == type(mbx_distinct))
      $fatal(1, "nominally distinct class mailbox actuals aliased");
    if (type(mbx_untyped) != type(mbx_explicit_default))
      $fatal(1, "mailbox and mailbox#() default types diverged");

    mbx_int = new();
    int_value = 17;
    if (!mbx_int.try_put(int_value))
      $fatal(1, "typed try_put failed");
    int_result = 0;
    if (!mbx_int.try_peek(int_result) || int_result != 17)
      $fatal(1, "typed try_peek failed");
    int_result = 0;
    if (!mbx_int.try_get(int_result) || int_result != 17)
      $fatal(1, "typed try_get failed");

    // A typedef does not create a new class type. Exercise every function-form
    // typed mailbox check with the alias as the actual and the declaration's
    // nominal class as the result type.
    mbx_nominal = new();
    nominal_value = new();
    nominal_value.payload = 37;
    if (!mbx_nominal.try_put(nominal_value))
      $fatal(1, "class-alias typed try_put failed");
    nominal_result = null;
    if (!mbx_nominal.try_peek(nominal_result)
        || nominal_result == null || nominal_result.payload != 37)
      $fatal(1, "class-alias typed try_peek failed");
    nominal_result = null;
    if (!mbx_nominal.try_get(nominal_result)
        || nominal_result == null || nominal_result.payload != 37)
      $fatal(1, "class-alias typed try_get failed");

    // Bare mailbox and explicit mailbox#() both accept heterogeneous message
    // sequences; only a concrete type actual activates equivalence checking.
    mbx_untyped = new();
    int_value = 23;
    string_value = "bare";
    mbx_untyped.put(int_value);
    mbx_untyped.put(string_value);
    mbx_untyped.get(int_result);
    mbx_untyped.get(string_result);
    if (int_result != 23 || string_result != "bare")
      $fatal(1, "bare mailbox lost dynamic message behavior");

    mbx_explicit_default = new();
    int_value = 29;
    string_value = "default";
    mbx_explicit_default.put(int_value);
    mbx_explicit_default.put(string_value);
    mbx_explicit_default.get(int_result);
    mbx_explicit_default.get(string_result);
    if (int_result != 29 || string_result != "default")
      $fatal(1, "mailbox#() lost dynamic message behavior");

    $display("PASSED");
  end
endmodule
