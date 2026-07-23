// Typed mailboxes with string and real messages (IEEE 1800-2017 15.4).
// String messages used to be boxed as vec4 string-bits; get() then
// stored them into the string variable through recv_vec4, which
// aborted the runtime ("recv_vec4 not implemented").
module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  initial begin
    automatic mailbox #(string) ms = new(2);
    automatic mailbox #(real) mr = new();
    automatic mailbox #(int) mi = new();
    automatic string s;
    automatic real r;
    automatic int i;

    // string messages, FIFO order, bounded capacity
    ms.put("one");
    ms.put("two");
    check("ms num", ms.num() == 2);
    check("ms full", ms.try_put("three") == 0);
    ms.get(s);
    check("ms fifo", s == "one" && ms.num() == 1);
    check("ms try_get", ms.try_get(s) == 1 && s == "two" && ms.num() == 0);
    check("ms empty", ms.try_get(s) == 0);

    // real messages
    mr.put(1.5);
    mr.put(-2.25);
    mr.get(r);
    check("mr fifo", r == 1.5);
    check("mr try", mr.try_get(r) == 1 && r == -2.25);

    // int messages still work
    mi.put(42);
    mi.get(i);
    check("mi", i == 42);

    if (!failed) $display("PASSED");
  end
endmodule
