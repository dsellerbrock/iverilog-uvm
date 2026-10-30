// IEEE 1800-2017/2023 18.6.3: a feasible size must be retried when the
// selected size makes the deferred foreach element constraints infeasible.
class holder;
  rand bit [7:0] d[];
  constraint c {
    d.size() inside {[0:3]};
    foreach (d[i]) d[i] == 8'h00 && d[i] == 8'h01;
  }
endclass

module main;
  holder h;
  int n;
  bit ok;
  initial begin
    h = new;
    repeat (20) begin
      ok = h.randomize();
      n += ok && h.d.size() == 0;
    end
    $display("class %0d", n);
  end
endmodule
