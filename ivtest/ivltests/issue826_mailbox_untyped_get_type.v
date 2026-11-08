// IEEE 1800-2023 15.4.5 / 15.4.7: a get() or peek() from a typeless mailbox
// "If the type of the message variable is not equivalent to the type of the
// message in the mailbox, a run-time error is generated." Equivalence of
// integral types is 6.22.2 c): same total bits, all 2-state or all 4-state,
// all signed or all unsigned. A mismatch leaves the variable unchanged; get()
// has removed the message, peek() has not.
module issue826_mailbox_untyped_get_type;
  typedef bit signed [7:0] sbyte_t;   // equivalent to byte (6.22.2 c)
  mailbox mb = new;
  mailbox #(int) typed = new;
  int i, j;
  integer ig;
  logic [31:0] l;
  bit [31:0] u;
  bit [7:0] ub;
  byte b;
  sbyte_t sb;
  logic [7:0] lv, lv2;
  string s;
  real r;
  bit fail = 0;

  task automatic expect_int(input string what, input int got, input int exp);
    if (got !== exp) begin
      $display("FAILED %s: got %0d expected %0d", what, got, exp);
      fail = 1;
    end
  endtask

  initial begin
    // Mismatches: the variable keeps its value.
    i = 11;
    mb.put("text"); mb.get(i);
    expect_int("string->int", i, 11); expect_int("string->int num", mb.num(), 0);
    mb.put(8'd7); mb.peek(i);
    expect_int("8'd7->int peek", i, 11); expect_int("peek keeps message", mb.num(), 1);
    mb.get(b);                       // 8 bits, but unsigned vs signed byte
    expect_int("8'd7->byte", b, 0); expect_int("get removes message", mb.num(), 0);
    j = 5;
    l = 1; mb.put(j); mb.get(l); expect_int("int->logic[31:0]", l, 1);
    u = 1; mb.put(j); mb.get(u); expect_int("int->bit[31:0]", u, 1);
    ig = 1; mb.put(j); mb.get(ig); expect_int("int->integer", ig, 1);

    // Equivalent types keep working.
    mb.put(j); mb.get(i); expect_int("int->int", i, 5);
    mb.put(8'd7); mb.get(ub); expect_int("8'd7->bit[7:0]", ub, 7);
    b = -3; mb.put(b); mb.get(sb); expect_int("byte->sbyte_t", sb, -3);
    lv = 8'b1010x01z; mb.put(lv); mb.get(lv2);
    if (lv2 !== 8'b1010x01z) begin $display("FAILED logic[7:0]"); fail = 1; end
    mb.put("str"); mb.get(s);
    if (s != "str") begin $display("FAILED string"); fail = 1; end
    mb.put(2.5); mb.get(r);
    if (r != 2.5) begin $display("FAILED real"); fail = 1; end

    // A get that blocks before its put is checked when it resumes.
    i = 11;
    fork
      mb.get(i);
      #1 mb.put("late");
    join
    expect_int("blocked string->int", i, 11);
    fork
      mb.get(i);
      #1 mb.put(j);
    join
    expect_int("blocked int->int", i, 5);

    // A parameterized mailbox is checked when compiled (15.4.9), not here.
    j = 3; typed.put(j); typed.get(i); expect_int("mailbox #(int)", i, 3);

    if (!fail) $display("PASSED");
  end
endmodule
