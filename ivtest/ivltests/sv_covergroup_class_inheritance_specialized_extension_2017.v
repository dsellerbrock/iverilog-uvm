class base #(type T = int);
  T a;
  covergroup cg;
    cp: coverpoint a { bins z = {0}; bins nz = {[1:15]}; }
  endgroup
  function new; cg = new; endfunction
endclass

class derived #(type T = int) extends base#(T);
  covergroup extends cg;
  endgroup : cg
endclass

module test;
  derived#(int) di = new;
  derived#(bit [3:0]) db = new;
endmodule
