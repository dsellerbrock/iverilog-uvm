module test;
  int declaration_weight = 2;
  covergroup cg(int increment) with function sample(int v);
    option.weight = declaration_weight + increment;
    cp: coverpoint v { bins b[] = {[0:1]}; }
  endgroup
  class owner;
    int seed;
    function int option_weight(); return seed + 1; endfunction
    covergroup embedded with function sample(int v);
      option.weight = option_weight();
      cp: coverpoint v { bins b[] = {[0:1]}; }
    endgroup
    function new(int value);
      seed=value;
      embedded=new;
    endfunction
  endclass
  owner a,b;
  task automatic construct(int increment);
    int declaration_weight = 100;
    cg item;
    item=new(increment);
    if (item.option.weight != 2+increment)
      $fatal(1,"option lexical scope or constructor isolation");
  endtask
  initial begin
    fork construct(1); construct(3); join
    a=new(2); b=new(4);
    if (a.embedded.option.weight != 3 || b.embedded.option.weight != 5)
      $fatal(1,"enclosing method option initializer");
    $display("PASSED");
  end
endmodule
