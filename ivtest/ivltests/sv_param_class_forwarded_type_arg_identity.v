// seqr#(int) reached as the type argument of a base-class specialization
// (dv_agent#(seqr#(int))) is the same type as seqr#(int) anywhere else, even
// when a generic class elaborates dv_agent#(seqr#(T)) first. The generic
// seed's forwarded seqr#(T) printed the same key, so dv_agent#(seqr#(int))
// reused it and $cast failed -- OpenTitan's dv_base_seq p_sequencer cast.
class base; endclass
class seqr #(type T = int) extends base; endclass
class dv_agent #(type S = base);
  S s;
  function new(); s = new; endfunction
endclass
class agent #(type T = int) extends dv_agent #(seqr#(T)); endclass
class agent_int extends dv_agent #(seqr#(int)); endclass
class dv_seq #(type S = base);
  S p;
  function bit set(base m); return $cast(p, m); endfunction
endclass
class my_seq #(type T = int) extends dv_seq #(seqr#(T)); endclass

module test;
  initial begin
    automatic agent a = new;
    automatic agent_int ai = new;
    automatic my_seq q = new;
    automatic dv_seq #(seqr#(int)) d = new;
    automatic seqr #(int) plain = new;
    if (d.set(plain) && d.set(ai.s) && d.set(a.s)
        && q.set(plain) && q.set(ai.s) && q.set(a.s))
      $display("PASSED");
    else
      $display("FAILED: %0d %0d %0d %0d %0d %0d", d.set(plain), d.set(ai.s),
               d.set(a.s), q.set(plain), q.set(ai.s), q.set(a.s));
  end
endmodule
