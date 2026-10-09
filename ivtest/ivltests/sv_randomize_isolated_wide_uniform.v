// IEEE 1800-2017 18.5.10 / 1800-2023 18.5.9: every legal value combination is
// equally likely. A 32-bit variable whose constraints mention no other free
// variable is sampled exactly, not by nearest-to-random-target search, which
// picked x == 0 about half the time below (expected about 1 in 4097).
class lone_zero;
  rand bit [31:0] x;
  constraint c { x inside {32'h0, [32'h1000:32'h1FFF]}; }
endclass
class strided_addr;
  rand bit [1:0] kind;
  rand bit [7:0] len;
  rand bit [31:0] addr;
  constraint c_kind { kind dist {0 := 4, 1 := 4, 2 := 1}; }
  constraint c_len { len inside {[1:16]}; (kind == 2) -> len == 1; }
  constraint c_addr {
    addr inside {[32'h1000:32'h1FFF], [32'h8000:32'h8FFF]};
    addr[1:0] == 0;
  }
endclass
module main;
  initial begin
    lone_zero z = new;
    strided_addr s = new;
    int zeros = 0, low = 0, bad = 0;
    for (int i = 0; i < 400; i++) begin
      if (!z.randomize()) bad++;
      if (z.x == 0) zeros++;
      else if (z.x < 32'h1000 || z.x > 32'h1FFF) bad++;
    end
    for (int i = 0; i < 400; i++) begin
      if (!s.randomize()) bad++;
      if (s.addr[1:0] != 0) bad++;
      if (s.addr >= 32'h1000 && s.addr <= 32'h1FFF) low++;
      else if (!(s.addr >= 32'h8000 && s.addr <= 32'h8FFF)) bad++;
      if (s.len < 1 || s.len > 16 || (s.kind == 2 && s.len != 1)) bad++;
    end
    // zeros: mean 0.1. low: Binomial(400, 0.5), mean 200, sd 10.
    if (bad == 0 && zeros <= 5 && low >= 140 && low <= 260)
      $display("PASSED");
    else
      $display("FAILED bad=%0d zeros=%0d low=%0d", bad, zeros, low);
  end
endmodule
