class C #(int N = 1); endclass
class D extends C#(1); endclass
module issue3112_pass;
  C a;
  C#(1) b;
  D d;
  function C#(1) get_b(); return b; endfunction
  initial begin
    b = new;
    a = b;
    if (a != b) $fatal(1, "matching specializations");
    a = get_b();
    if (a != b) $fatal(1, "matching return type");
    d = new;
    a = d;
    if (a != d) $fatal(1, "derived specialization");
    a = null;
    $display("PASS");
  end
endmodule
