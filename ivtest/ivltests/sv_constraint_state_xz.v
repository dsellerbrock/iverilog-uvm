// IEEE 1800-2017/2023 18.3: X/Z caller state is an error where used, but
// an inactive implication branch remains legal. Failed calls preserve rand
// values, including when the unknown is above bit 63 of a runtime slot.
class item; rand bit [2:0] lanes; endclass
class seq;
  logic [2:0] x;
  logic [64:0] wide_x;
  bit g;
  function int run(item it); return it.randomize() with { lanes == x; }; endfunction
  function int guarded(item it); return it.randomize() with { g -> lanes == x; }; endfunction
  function int wide_run(item it); return it.randomize() with { lanes == wide_x; }; endfunction
  function int wide_guarded(item it); return it.randomize() with { g -> lanes == wide_x; }; endfunction
endclass
module top;
  seq s; item it; bit [2:0] sv; logic [2:0] sx;
  bit [64:0] sv_wide; logic [64:0] sx_wide; int errs;
  initial begin
    s = new; it = new;
    it.lanes = 5; s.x = 3'b0x1;
    if (s.run(it) != 0 || it.lanes != 5) begin $display("FAILED unguarded"); errs++; end
    s.g = 0;
    if (s.guarded(it) != 1) begin $display("FAILED inactive guard"); errs++; end
    s.g = 1; it.lanes = 6;
    if (s.guarded(it) != 0 || it.lanes != 6) begin $display("FAILED active guard"); errs++; end
    s.x = 3'b010;
    if (s.run(it) != 1 || it.lanes != 2) begin $display("FAILED known 4-state"); errs++; end
    s.wide_x = 65'hx0000000000000000;
    s.g = 0;
    if (s.wide_guarded(it) != 1) begin $display("FAILED inactive wide guard"); errs++; end
    s.g = 1; it.lanes = 4;
    if (s.wide_guarded(it) != 0 || it.lanes != 4) begin $display("FAILED wide X guard"); errs++; end
    s.wide_x = 65'hz0000000000000000; it.lanes = 3;
    if (s.wide_run(it) != 0 || it.lanes != 3) begin $display("FAILED wide Z"); errs++; end
    sx = 3'bz00; sv = 7;
    if (std::randomize(sv) with { sv == sx; } != 0 || sv != 7) begin $display("FAILED std::randomize"); errs++; end
    sx_wide = 65'hx0000000000000000; sv_wide = 65'h5;
    if (std::randomize(sv_wide) with { sv_wide == sx_wide; } != 0 || sv_wide != 65'h5)
      begin $display("FAILED wide std::randomize"); errs++; end
    if (errs == 0) $display("PASSED");
  end
endmodule
