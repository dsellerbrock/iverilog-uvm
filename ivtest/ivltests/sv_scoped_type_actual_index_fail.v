class types;
  typedef int word_t;
endclass
class holder;
  typedef types nested_t;
endclass
class generic #(type T=int);
  typedef T word_t;
endclass
class accept #(type T=int);
  static function int width(); return $bits(T); endfunction
endclass
module main;
  initial begin
    $display("%0d",accept#(types::word_t[0])::width());
    $display("%0d",accept#(generic::word_t)::width());
    $display("%0d",accept#(holder::nested_t.word_t)::width());
  end
endmodule
