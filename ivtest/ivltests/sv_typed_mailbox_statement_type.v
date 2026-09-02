// IEEE 1800-2017/2023 15.4.9: each statement-form mailbox message method
// accepts an actual whose type is equivalent to the typed mailbox carrier.
class mailbox_statement_message;
  int payload;
endclass

typedef mailbox_statement_message mailbox_statement_message_alias_t;
typedef struct packed {
  logic [15:0] value;
} mailbox_statement_packed_a_t;
typedef struct packed {
  logic [7:0] high;
  logic [7:0] low;
} mailbox_statement_packed_b_t;

module sv_typed_mailbox_statement_type;
  mailbox #(int) mbx;
  mailbox #(mailbox_statement_message) class_mbx;
  mailbox #(mailbox_statement_packed_a_t) packed_mbx;
  int value;
  mailbox_statement_message_alias_t class_value;
  mailbox_statement_message class_result;
  mailbox_statement_packed_a_t packed_result;
  mailbox_statement_packed_b_t packed_value;

  initial begin
    mbx = new();

    // Unsized integral literals carry their self-determined scalar type in
    // the expression even when there is no explicit ivl_type_t object.
    mbx.put(17);
    value = 0;
    mbx.peek(value);
    if (value != 17)
      $fatal(1, "typed mailbox peek lost the message");
    value = 0;
    mbx.get(value);
    if (value != 17)
      $fatal(1, "typed mailbox get returned the wrong message");

    mbx.try_put(23);
    value = 0;
    mbx.try_peek(value);
    if (value != 23)
      $fatal(1, "typed mailbox try_peek lost the message");
    value = 0;
    mbx.try_get(value);
    if (value != 23)
      $fatal(1, "typed mailbox try_get returned the wrong message");

    // A typedef aliases the same nominal class. Cover the task methods and the
    // discarded-result statement forms of all three try_* functions with the
    // alias as an input actual and the declared class as an output actual.
    class_mbx = new();
    class_value = new();
    class_value.payload = 31;
    class_mbx.put(class_value);
    class_result = null;
    class_mbx.peek(class_result);
    if (class_result == null || class_result.payload != 31)
      $fatal(1, "class-alias typed mailbox peek lost the message");
    class_result = null;
    class_mbx.get(class_result);
    if (class_result == null || class_result.payload != 31)
      $fatal(1, "class-alias typed mailbox get returned the wrong message");

    class_value = new();
    class_value.payload = 37;
    class_mbx.try_put(class_value);
    class_result = null;
    class_mbx.try_peek(class_result);
    if (class_result == null || class_result.payload != 37)
      $fatal(1, "class-alias typed mailbox try_peek lost the message");
    class_result = null;
    class_mbx.try_get(class_result);
    if (class_result == null || class_result.payload != 37)
      $fatal(1, "class-alias typed mailbox try_get returned the wrong message");

    // Distinct packed-structure declarations do not match (6.22.1), but are
    // equivalent when width, state domain, and signing agree (6.22.2(c)).
    // Section 15.4.9 requires equivalence, so this transfer is legal.
    packed_mbx = new();
    packed_value.high = 8'h12;
    packed_value.low = 8'h34;
    packed_mbx.put(packed_value);
    packed_result = '0;
    packed_mbx.get(packed_result);
    if (packed_result.value !== 16'h1234)
      $fatal(1, "equivalent packed-structure mailbox transfer failed");

    $display("PASSED");
  end
endmodule
