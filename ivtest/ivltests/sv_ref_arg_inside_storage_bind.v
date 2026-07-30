// R25 companion-path matrix: detached (join_none) write through a ref
// formal, task returns before the write. IEEE 13.5.2: ref binds the
// ACTUAL; the caller variable is alive, so the write must land.
class obj_c;
  int p = 0;
  real pr = 0.0;
endclass

module top;
  int direct_v = 0;
  int arr[4];
  int q[$];
  int da[];
  real rarr[4];
  obj_c o;
  int static_v = 0;
  typedef struct { int f; } st_t;
  st_t s;
  int fails = 0;

  task automatic wi(ref int x);    fork #1 x = 42;    join_none endtask
  task automatic wr(ref real x);   fork #1 x = 3.5;   join_none endtask

  initial begin
    arr[2] = 0; q.push_back(0); da = new[2]; o = new;

    wi(direct_v);
    wi(arr[2]);
    wi(q[0]);
    wi(da[1]);
    wi(o.p);
    wi(static_v);
    wi(s.f);
    wr(rarr[3]);

    #10;
    if (direct_v != 42) begin fails++; $display("FAIL direct_v=%0d", direct_v); end
    if (arr[2] != 42)   begin fails++; $display("FAIL arr[2]=%0d", arr[2]); end
    if (q[0] != 42)     begin fails++; $display("FAIL q[0]=%0d", q[0]); end
    if (da[1] != 42)    begin fails++; $display("FAIL da[1]=%0d", da[1]); end
    if (o.p != 42)      begin fails++; $display("FAIL o.p=%0d", o.p); end
    if (static_v != 42) begin fails++; $display("FAIL static_v=%0d", static_v); end
    if (s.f != 42)      begin fails++; $display("FAIL s.f=%0d", s.f); end
    if (rarr[3] != 3.5) begin fails++; $display("FAIL rarr[3]=%f", rarr[3]); end
    if (fails == 0) $display("PASSED");
    else $display("FAIL count=%0d", fails);
  end
endmodule
