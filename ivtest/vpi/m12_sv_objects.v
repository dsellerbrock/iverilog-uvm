// M12: VPI SystemVerilog object model regression.
module top;
  int i = 42;
  string s = "hello";
  int da[];
  int q[$];
  int aa[string];
  class C;
    int count = 7;
    string name = "c0";
    real ratio = 2.5;
  endclass
  C obj;
  initial begin
    da = new[3];
    da[1] = 33;
    q.push_back(10);
    q.push_back(20);
    aa["b"] = 5;
    aa["a"] = 4;
    obj = new;
    $m12_setup;
    $m12_probe;
    #1 s = "changed";
    #1 $display("final: s='%s' da[1]=%0d obj.count=%0d obj.name='%s'",
                s, da[1], obj.count, obj.name);
  end
endmodule
