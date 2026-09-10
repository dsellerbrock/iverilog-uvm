package scoped_types;
  typedef logic [2:0] word_t;
  class types #(type E=byte);
    typedef E word_t;
  endclass
  class inherited extends types#(logic [12:0]); endclass
  typedef types#(logic [20:0]) alias_t;
  class accept #(type T=int);
    static function int width(); return $bits(T); endfunction
  endclass
  class probe;
    typedef bit word_t;
    function bit check();
      return accept#(types#(logic [8:0])::word_t)::width()==9 &&
             accept#(types#(logic [16:0])::word_t)::width()==17 &&
             accept#(inherited::word_t)::width()==13 &&
             accept#(alias_t::word_t)::width()==21 &&
             accept#(scoped_types::alias_t::word_t)::width()==21;
    endfunction
  endclass
endpackage
module main;
  import scoped_types::*;
  probe obj;
  initial begin
    obj=new;
    if (!obj.check()) $fatal(1,"scoped type specialization or shadowing lost");
    $display("PASSED"); $finish(0);
  end
endmodule
