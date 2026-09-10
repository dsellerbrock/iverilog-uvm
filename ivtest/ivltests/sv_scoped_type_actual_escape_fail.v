package p;
  typedef longint missing_t;
  class empty; endclass
  class selected;
    typedef byte word_t;
  endclass
  class accept #(type T=int);
    static function int width(); return $bits(T); endfunction
  endclass
  class probe;
    typedef int selected;
    function int check();
      return accept#(empty::missing_t)::width()+accept#(selected::word_t)::width();
    endfunction
  endclass
endpackage
module main;
  import p::*;
  probe obj;
  initial begin obj=new; $display("%0d",obj.check()); end
endmodule
