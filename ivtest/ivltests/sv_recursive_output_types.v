// IEEE1800-2017/2023 13.5: preserve typed copy-out and virtual dispatch.
module sv_recursive_output_types;
  class box; int value; endclass
  class C;
    function int produce(output int a, output real b, output string c,
                         output box d, output int q[$], output int fixed_values[2],
                         inout int acc, ref int shared);
      a=37; b=2.5; c="copied"; d=new; d.value=41;
      q='{7,9}; fixed_values='{13,17}; acc+=5; shared++;
      return 0;
    endfunction
    function void recurse(int depth);
      int a=-1, acc=10, shared=20, q[$], fixed_values[2];
      real b=-1.0;
      string c="old";
      box d;
      if(depth!=0) begin
        recurse(produce(a,b,c,d,q,fixed_values,acc,shared));
        if(a!=37 || b!=2.5 || c!="copied" || d==null || d.value!=41 ||
           q.size()!=2 || q[0]!=7 || q[1]!=9 || fixed_values[0]!=13 ||
           fixed_values[1]!=17 || acc!=15 || shared!=21) $fatal(1,"typed outputs");
      end
    endfunction
  endclass
  class Base;
    virtual function int produce(output int a); a=-1; return 0; endfunction
  endclass
  class Derived extends Base;
    virtual function int produce(output int a); a=77; return 0; endfunction
  endclass
  class V;
    Base impl;
    function void recurse(int depth);
      int a=-1;
      if(depth!=0) begin
        recurse(impl.produce(a));
        if(a!=77) $fatal(1,"virtual output %0d",a);
      end
    endfunction
  endclass
  initial begin
    C c; V v; Derived d;
    c=new; v=new; d=new; v.impl=d;
    c.recurse(1); v.recurse(1);
    $display("PASSED");
  end
endmodule
