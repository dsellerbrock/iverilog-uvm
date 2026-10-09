// -gcommercial-unsafe still rejects values that are not assignment
// compatible, and get/peek (ref arguments) still require equivalence.
class base; endclass
class derived extends base; endclass
module main;
  mailbox #(derived) md = new;
  mailbox #(int) mi = new;
  mailbox #(base) mb = new;
  initial begin
    automatic base b = new;
    derived d;
    automatic string s = "x";
    md.put(b);       // base handle is not assignment compatible with derived
    void'(md.try_put(b));
    mi.put(s);       // string is not assignment compatible with int
    mb.get(d);       // ref argument needs an equivalent type
  end
endmodule
