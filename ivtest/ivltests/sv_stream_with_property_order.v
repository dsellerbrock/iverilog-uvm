typedef logic [7:0] byte_q_t[$];

class stream_inner_c;
  logic [7:0] d[];
  logic [7:0] q[$];
  logic [7:0] f[3:1];
  string s;
endclass

class stream_outer_c;
  stream_inner_c inner;
  logic [7:0] d[];
endclass

class stream_cell_c;
  logic [7:0] d[];
endclass

module test;
  stream_outer_c obj;
  stream_outer_c nil;
  stream_cell_c cells[$];
  stream_cell_c cell_obj;
  byte_q_t source_q;
  int sequence_log;
  int receiver_calls;
  int first_calls;
  int width_calls;
  int errors;
  logic [15:0] got;

  function byte_q_t get_q();
    receiver_calls += 1;
    sequence_log = sequence_log * 10 + 1;
    return source_q;
  endfunction
  function int pick();
    first_calls += 1;
    sequence_log = sequence_log * 10 + 2;
    return 1;
  endfunction
  function int span();
    width_calls += 1;
    sequence_log = sequence_log * 10 + 3;
    return 2;
  endfunction
  function int choose();
    receiver_calls += 1;
    sequence_log = sequence_log * 10 + 1;
    return 0;
  endfunction
  task automatic check(input bit ok, input string what);
    if (!ok) begin
      errors += 1;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    obj = new;
    obj.inner = new;
    obj.d = '{8'haa};
    obj.inner.d = '{8'hbb, 8'hcc, 8'hdd};
    obj.inner.q = '{8'hee};
    obj.inner.f = '{8'h31, 8'h21, 8'h11};
    obj.inner.s = "old";

    {>>{obj.d}} = 16'h1234;
    {>>{obj.inner.d}} = 24'h405060;
    {>>{obj.inner.q}} = 16'h7182;
    {>>{obj.inner.s}} = 32'h41424344;
    check(obj.d.size() == 2 && obj.d[0] == 8'h12 && obj.d[1] == 8'h34,
          "whole dynamic property store");
    check(obj.inner.d[0] == 8'h40 && obj.inner.d[1] == 8'h50
          && obj.inner.d[2] == 8'h60, "nested dynamic property store");
    check(obj.inner.q.size() == 2 && obj.inner.q[0] == 8'h71
          && obj.inner.q[1] == 8'h82, "nested queue property store");
    check(obj.inner.s == "ABCD", "nested string property store");

    {>>{obj.inner.d with [1 +: 2]}} = 16'h91a2;
    {>>{obj.inner.q with [1 +: 2]}} = 16'hb3c4;
    {>>{obj.inner.f with [2 -: 2]}} = 16'hd5e6;
    check(obj.inner.d[0] == 8'h40 && obj.inner.d[1] == 8'h91
          && obj.inner.d[2] == 8'ha2, "ranged dynamic property store");
    check(obj.inner.q.size() == 3 && obj.inner.q[0] == 8'h71
          && obj.inner.q[1] == 8'hb3 && obj.inner.q[2] == 8'hc4,
          "ranged queue property store");
    check(obj.inner.f[3] == 8'h31 && obj.inner.f[2] == 8'hd5
          && obj.inner.f[1] == 8'he6, "ranged fixed property store");

    source_q = '{8'h10, 8'h21, 8'h32, 8'h43};
    sequence_log = 0; receiver_calls = 0; first_calls = 0; width_calls = 0;
    got = {>>{get_q() with [pick() +: span()]}};
    check(sequence_log == 123 && receiver_calls == 1 && first_calls == 1
          && width_calls == 1 && got == 16'h2132,
          "source receiver, first, and width evaluate once in order");

    cell_obj = new;
    cell_obj.d = '{8'haa, 8'hbb, 8'hcc};
    cells.push_back(cell_obj);
    sequence_log = 0; receiver_calls = 0; first_calls = 0; width_calls = 0;
    {>>{cells[choose()].d with [pick() +: span()]}} = 16'h5566;
    check(sequence_log == 123 && receiver_calls == 1 && first_calls == 1
          && width_calls == 1, "target receiver and range evaluation order");
    check(cells[0].d[0] == 8'haa && cells[0].d[1] == 8'h55
          && cells[0].d[2] == 8'h66, "indexed nested target identity");

    // A null receiver is a no-op and must leave no object/vector stack debt.
    {>>{nil.d}} = 8'hff;
    {>>{nil.d with [0]}} = 8'hee;

    if (errors == 0) $display("PASSED");
    else $display("FAILED: %0d checks", errors);
  end
endmodule
