// IEEE 1800-2017/2023 7.12.2: sort(), rsort(), reverse() and shuffle() on a
// one-dimensional fixed-size array that is a class property. The code generator
// warned "on an unsupported receiver shape; skipping" and left the property
// unchanged (OpenTitan flash_ctrl shuffles a property array to pick a bit to flip).
class holder;
  int w[4];
  int signed s[4];
  bit [7:0] u[5];
  function void load();
    w = '{3, 1, 2, 0};
    s = '{2, -5, 7, -1};
    u = '{8'd200, 8'd3, 8'd100, 8'd3, 8'd255};
  endfunction
endclass

module main;
  holder h;
  int errors;
  int seen_moved;
  initial begin
    h = new;
    h.load();
    h.w.sort();
    if (h.w[0] !== 0 || h.w[1] !== 1 || h.w[2] !== 2 || h.w[3] !== 3) begin
      $display("FAILED sort %0d %0d %0d %0d", h.w[0], h.w[1], h.w[2], h.w[3]); errors++;
    end
    h.w.reverse();
    if (h.w[0] !== 3 || h.w[3] !== 0) begin $display("FAILED reverse"); errors++; end
    h.w.rsort();
    if (h.w[0] !== 3 || h.w[1] !== 2 || h.w[2] !== 1 || h.w[3] !== 0) begin
      $display("FAILED rsort"); errors++;
    end

    h.s.sort();
    if (h.s[0] !== -5 || h.s[1] !== -1 || h.s[2] !== 2 || h.s[3] !== 7) begin
      $display("FAILED signed sort %0d %0d %0d %0d", h.s[0], h.s[1], h.s[2], h.s[3]); errors++;
    end

    h.u.rsort();
    if (h.u[0] !== 8'd255 || h.u[1] !== 8'd200 || h.u[2] !== 8'd100 || h.u[4] !== 8'd3) begin
      $display("FAILED unsigned rsort"); errors++;
    end

    // shuffle keeps the same multiset; over many tries the order must change.
    for (int t = 0; t < 20; t++) begin
      int sum;
      h.w.sort();
      h.w.shuffle();
      sum = h.w[0] + h.w[1] + h.w[2] + h.w[3];
      if (sum !== 6) begin $display("FAILED shuffle lost an element"); errors++; end
      if (h.w[0] !== 0 || h.w[1] !== 1) seen_moved++;
    end
    if (seen_moved == 0) begin $display("FAILED shuffle never reordered"); errors++; end

    if (errors == 0) $display("PASSED");
  end
endmodule
