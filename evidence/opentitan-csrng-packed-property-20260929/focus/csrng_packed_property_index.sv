typedef enum logic [3:0] {Flag0 = 4'h1, Flag1 = 4'h2, Flag2 = 4'h3} flag_t;

class scoreboard;
  flag_t [2:0] cmd_flag0_previous;
  task check(int app);
    flag_t value;
    value = cmd_flag0_previous[app];
    if (value != Flag1) $fatal(1, "wrong packed element");
  endtask
endclass

module top;
  scoreboard sb;
  initial begin
    sb = new;
    sb.cmd_flag0_previous = {Flag0, Flag1, Flag2};
    sb.check(1);
    $display("PASSED");
  end
endmodule
