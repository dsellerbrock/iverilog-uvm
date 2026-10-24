module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  int r1, r2, r3, r4, x, y, c, d, e;
  logic [15:0] u, v;
  task my_task(input int a, b, inout int c, output int d, e);
    c = c + a; d = b; e = c;
  endtask
  task mytask3(a, b, output logic [15:0] u, v); u = a; v = b; endtask
  task early(output int o); o = 1; return; o = 2; endtask
  task empty_t(); endtask
  task st_keep(input int i, output int o); if (i) o = 5; endtask
  task automatic au_keep(input int i, output int o); if (i) o = 5; endtask
  task automatic mix(output int o); static int s; s++; o = s; endtask
  task st_conc(input int v, output int o); int loc; loc = v; #2 o = loc; endtask
  task automatic au_conc(input int v, output int o); int loc; loc = v; #2 o = loc; endtask
  initial begin
    c = 10; my_task(1, 2, c, d, e); chk("13.3.directions", c == 11 && d == 2 && e == 11);
    mytask3(3, 4, u, v); $display("INFO u=%0d v=%0d", u, v); chk("13.3.default_dir_type_logic", u == 1 && v == 0);
    early(x); chk("13.3.return_exits", x == 1); empty_t(); chk("13.3.empty_task", 1);
    st_keep(1, x); st_keep(0, y); chk("13.3.2.static_output_retained", y == 5);
    au_keep(1, x); au_keep(0, y); chk("13.3.2.auto_output_reinit", y == 0);
    mix(x); mix(y); chk("13.3.1.static_var_in_auto_task", x == 1 && y == 2);
    fork st_conc(1, r1); #1 st_conc(2, r2); join
    chk("13.3.2.static_shared_concurrent", r1 == 2 && r2 == 2);
    fork au_conc(1, r3); #1 au_conc(2, r4); join
    chk("13.3.2.auto_replicated", r3 == 1 && r4 == 2);
    $display("DONE fails=%0d", fails);
  end
endmodule
