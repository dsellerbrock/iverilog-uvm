typedef struct { int x; int y; } pt_t;
class holder;
  static pt_t pool[3];
endclass
module top;
  holder h;
  initial begin
    h = new;
    // Read-only: does the sorry count as an error, or does this compile
    // with the comparison dropped?
    if (h.pool[0].x != 3) $display("branch taken: x != 3");
    else $display("branch NOT taken: comparison says x == 3");
    $display("DONE");
  end
endmodule
