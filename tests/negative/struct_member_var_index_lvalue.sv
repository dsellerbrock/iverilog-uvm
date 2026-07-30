// A VARIABLE bit index into a packed-struct member l-value is not
// lowered yet; it must be a LOUD refusal. It used to abort the whole
// compiler: the reported user error was promoted into an
// ivl_assert(rc) crash (recovery C4).
typedef struct packed {
  logic [7:0] key;
} s_t;
module top;
  s_t s;
  int i;
  initial begin
    i = 3;
    s.key[i] = 1'b1;
  end
endmodule
