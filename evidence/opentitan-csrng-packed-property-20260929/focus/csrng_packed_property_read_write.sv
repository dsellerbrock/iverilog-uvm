// IEEE 1800-2017/2023 7.4 and 11.5.1: packed-array class property indices
// select bits of one property value, not distinct class-property slots.
typedef enum logic [3:0] { A = 4'h1, B = 4'h2, C = 4'h3, D = 4'h9 } flag_t;
class scoreboard;
  flag_t [2:0] flags;
  task check();
    int app;
    flag_t value;
    flags = 12'h123;
    app = 1;
    flags[app] = D;
    if (flags !== 12'h193)
      $fatal(1, "write changed neighbors: %h", flags);
    for (app = 0; app < 3; app++) begin
      value = flags[app];
      if (value !== (app == 0 ? C : app == 1 ? D : A))
        $fatal(1, "read app=%0d value=%h", app, value);
    end
    app = 3;
    value = flags[app];
    if (value !== 4'hx) $fatal(1, "out-of-range read: %h", value);
    flags[app] = D;
    if (flags !== 12'h193) $fatal(1, "out-of-range write: %h", flags);
  endtask
endclass
module top;
  scoreboard sb;
  initial begin
    sb = new;
    sb.check();
    $display("PASSED");
  end
endmodule
