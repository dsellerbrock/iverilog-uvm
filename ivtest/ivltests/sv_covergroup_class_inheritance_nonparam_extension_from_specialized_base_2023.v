class base #(type T = int);
  T a;
  covergroup cg;
    cp: coverpoint a { bins z = {0}; bins nz = {[1:15]}; }
  endgroup
  function new; cg = new; endfunction
endclass

class derived extends base#(int);
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  derived item = new;
  initial begin
    item.a = 5;
    item.cg.sample();
    if (item.cg.get_inst_coverage() != 50.0
        || item.cg.get_coverage() != 50.0)
      $fatal(1, "extension through a non-parameterized descendant failed");
    $display("PASSED");
    $finish;
  end
endmodule
