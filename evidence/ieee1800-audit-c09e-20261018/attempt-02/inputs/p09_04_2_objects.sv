module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  class Pk; int status; endclass
  Pk p, q, old;
  int hs, hh;
  time ts;
  initial begin
    p = new; q = new; old = p;
    fork
      begin @(p.status); hs++; ts = $time; end
      begin @p; hh++; end
      begin #10 p = q; #5 old.status = 7; #5 q.status = 9; #1; end
    join
    chk("9.4.2.handle_change_is_event", hh == 1);
    chk("9.4.2.member_event_retargets_to_new_object", hs == 1 && ts == 20);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
