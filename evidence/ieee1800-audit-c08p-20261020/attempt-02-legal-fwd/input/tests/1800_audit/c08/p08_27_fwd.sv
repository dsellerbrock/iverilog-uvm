// IEEE 1800 §8.27: forward class declarations, including a parameterized class.
typedef class C2;
class C1; C2 peer; int v = 1; endclass
class C2; C1 peer; int v = 2; endclass
typedef class P;
class U; P #(8) h; endclass
class P #(int W = 4); bit [W-1:0] x; endclass
module p08_27_fwd; C1 a; C2 b; U u;
  initial begin a = new; b = new; a.peer = b; b.peer = a; u = new; u.h = new;
    $display("FWD %0d %0d %0d", a.peer.v, b.peer.v, $bits(u.h.x)); end
endmodule
