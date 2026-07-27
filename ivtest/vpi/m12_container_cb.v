// cbValueChange on runtime-container elements, both direct and in a class.
module top;
  int q[$];
  int aa[string];

  class C;
    int q[$];
    int da[];
    int aa[string];
    string sq[$];
    real rd[];
    function new;
      q = {20, 21};
      da = new[2];
      da[0] = 30;
      da[1] = 31;
      aa["b"] = 41;
      aa["a"] = 40;
      sq.push_back("initial");
      rd = new[1];
      rd[0] = 1.5;
    endfunction
  endclass

  C obj;

  initial begin
    q.push_back(10);
    q.push_back(11);
    aa["a"] = 50;
    obj = new;
    $m12_container_cb_setup;
    #1;
    q[0] = 12;
    aa["a"] = 52;
    obj.q[0] = 22;
    obj.da[0] = 32;
    obj.aa["a"] = 42;
    obj.sq[0] = "sv";
    obj.rd[0] = 2.5;
    #1;
    $m12_container_cb_vpi_writes;
    #1;
    $m12_container_cb_check;
    $finish(0);
  end
endmodule
