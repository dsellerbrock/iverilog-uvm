// IEEE 1800-2017/2023 15.4.9: put/get/peek and the try_* variants require
// exact argument-type equivalence for a typed mailbox, including when a
// try_* function is called as a statement and its return value is discarded.
class mailbox_statement_expected;
endclass

class mailbox_statement_distinct;
endclass

module sv_typed_mailbox_statement_type_fail;
  mailbox #(int) mbx;
  mailbox #(mailbox_statement_expected) class_mbx;
  shortint wrong_type;
  mailbox_statement_distinct wrong_class;

  initial begin
    mbx = new();
    class_mbx = new();
    wrong_class = new();
    mbx.put(wrong_type);
    mbx.get(wrong_type);
    mbx.peek(wrong_type);
    mbx.try_put(wrong_type);
    mbx.try_get(wrong_type);
    mbx.try_peek(wrong_type);
    class_mbx.put(wrong_class);
    class_mbx.get(wrong_class);
    class_mbx.peek(wrong_class);
    class_mbx.try_put(wrong_class);
    class_mbx.try_get(wrong_class);
    class_mbx.try_peek(wrong_class);
  end
endmodule
