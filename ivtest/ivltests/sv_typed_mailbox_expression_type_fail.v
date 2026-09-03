// IEEE 1800-2017/2023 15.4.9: expression-form try_put/try_get/try_peek
// require an argument type equivalent to the concrete mailbox message type.
class mailbox_expression_expected;
endclass

class mailbox_expression_distinct;
endclass

module sv_typed_mailbox_expression_type_fail;
  mailbox #(int) mbx;
  mailbox #(mailbox_expression_expected) class_mbx;
  shortint wrong_type;
  mailbox_expression_distinct wrong_class;
  int status;

  initial begin
    mbx = new();
    class_mbx = new();
    wrong_class = new();
    status = mbx.try_put(wrong_type);
    status = mbx.try_get(wrong_type);
    status = mbx.try_peek(wrong_type);
    status = class_mbx.try_put(wrong_class);
    status = class_mbx.try_get(wrong_class);
    status = class_mbx.try_peek(wrong_class);
  end
endmodule
