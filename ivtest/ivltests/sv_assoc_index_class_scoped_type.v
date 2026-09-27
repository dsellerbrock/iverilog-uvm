// An associative array index type may be a class-scoped typedef
// (IEEE 1800-2017/2023 7.8, 8.23): `int r[C::e];'. The TYPE::member
// expression form wins the grammar conflict, so the index was treated as a
// hierarchical constant (OpenTitan usbdev scoreboard). The same holds for a
// cast to a class-scoped type, `C::e'(x)' (IEEE 6.24.1). A class-scoped
// value still sizes a fixed dimension.
package p;
  class regs;
    typedef enum { A, B } e;
    localparam int N = 4;
  endclass
endpackage

class timed_regs;
  typedef enum { RegA, RegB, RegC } timed_reg_e;
endclass

class sb;
  typedef struct {
    int r[timed_regs::timed_reg_e];
  } bfm_t;
  bfm_t s;
  int q[timed_regs::timed_reg_e];
  function bit run();
    int ep = 1;
    timed_regs::timed_reg_e r;
    s.r[timed_regs::RegB] = 5;
    q[timed_regs::timed_reg_e'(timed_regs::RegA + 2)] = 7;
    r = timed_regs::timed_reg_e'(timed_regs::RegA + ep);
    return s.r.num() == 1 && s.r[timed_regs::RegB] == 5
	   && q.num() == 1 && q[timed_regs::RegC] == 7 && r == timed_regs::RegB;
  endfunction
endclass

module test;
  int w[p::regs::N];
  int a[p::regs::e];
  initial begin
    automatic sb o = new;
    a[p::regs::e'(1)] = 3;
    if (o.run() && $size(w) == 4 && a.num() == 1 && a[p::regs::B] == 3)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
