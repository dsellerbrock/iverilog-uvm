// -gcommercial-unsafe: typed mailbox put/try_put accept an assignment-
// compatible value (derived handle, null, integral/real conversion), as
// commercial simulators do. IEEE 1800-2017/2023 15.4.9 requires equivalent
// types, which the default mode enforces (sv_typed_mailbox_*_type_fail).
class base;
  int id;
  function new(int i); id = i; endfunction
  virtual function string kind(); return "base"; endfunction
endclass
class derived extends base;
  function new(int i); super.new(i); endfunction
  virtual function string kind(); return "derived"; endfunction
endclass
module main;
  mailbox #(base) mb = new;
  mailbox #(int) mi = new;
  mailbox #(string) ms = new;
  initial begin
    derived d = new(7), d8 = new(8);
    base b;
    int i;
    byte sb = -3;
    string s, lit;
    bit ok = 1;
    mb.put(d);
    if (!mb.try_put(d8)) ok = 0;
    mb.put(null);
    mb.get(b);  if (b == null || b.id != 7 || b.kind() != "derived") ok = 0;
    mb.get(b);  if (b == null || b.id != 8 || b.kind() != "derived") ok = 0;
    mb.get(b);  if (b != null) ok = 0;
    mi.put(sb);              // byte -> int, sign-extended
    mi.put(4'hF);               // unsized-width literal -> int
    mi.get(i);  if (i != -3) ok = 0;
    mi.get(i);  if (i != 15) ok = 0;
    mi.put(4'b1x0z);            // 4-state -> 2-state: X/Z become 0
    mi.put(2.7);                // real -> int rounds
    mi.get(i);  if (i != 8) ok = 0;
    mi.get(i);  if (i != 3) ok = 0;
    s = "var";
    ms.put("lit");
    ms.put(s);
    ms.get(lit); if (lit != "lit") ok = 0;
    ms.get(s);   if (s != "var") ok = 0;
    if (ok) $display("PASSED"); else $display("FAILED");
  end
endmodule
