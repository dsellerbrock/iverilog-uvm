// `obj.q[i][j]' where obj.q is a class-property `string q[$]' -- a
// container index (queue element select) followed by a string
// character/byte select -- used to hit "sorry: this index does not
// select a queue or associative-array class-property value" even
// though a bare `string_var[j]' (no class-property queue involved)
// already worked via the identical NetESelect shape, and a second
// CONTAINER index (e.g. int queue-of-queues) already worked too (L39).

module test;
  class c;
    string q[$];
  endclass
  c obj;
  byte ch;
  int errors;

  initial begin
    errors = 0;
    obj = new;
    obj.q.push_back("hello");
    obj.q.push_back("world");

    ch = obj.q[0][1];
    if (ch != "e") begin
      $display("FAILED: obj.q[0][1] expected 'e', got '%c'", ch);
      errors = errors + 1;
    end

    ch = obj.q[1][0];
    if (ch != "w") begin
      $display("FAILED: obj.q[1][0] expected 'w', got '%c'", ch);
      errors = errors + 1;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
