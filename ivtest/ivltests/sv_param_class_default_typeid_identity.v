// UVM-style self registry: a#(int)::type_id::create() must create an
// a#(int) even though int is a's default. Inside a's template body, a#(K)
// names the generic master, whose cache description equalled a#(int)'s, so
// registry#(a#(int)) was bound to the master and created master objects.
class base; endclass
class registry #(type T = base);
  static int created;
  static function base create(); T o = new; return o; endfunction
endclass
class a #(type K = int) extends base;
  typedef registry #(a#(K)) type_id;
  static function base make(); a#(K) o = new; return o; endfunction
endclass
typedef a#(int) ai_t;

module test;
  initial begin
    a#(int) c;
    a#(byte) cb;
    if ($cast(c, a#(int)::type_id::create()) && $cast(c, ai_t::type_id::create())
        && $cast(c, a#(int)::make()) && $cast(c, registry#(a#(int))::create())
        && $cast(cb, a#(byte)::type_id::create()))
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
