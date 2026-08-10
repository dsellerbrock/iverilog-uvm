// IEEE 1800-2017 7.10.1: a queue suffix slice is an l-value. Assignment
// replaces exactly the existing elements lo through $, without resizing.
module main;
  class box;
    int value;
    function new(int v);
      value = v;
    endfunction
  endclass

  bit failed;
  int lo_calls;
  int iq[$], ir[$];
  logic [7:0] vq[$], vr[$];
  real rq[$], rr[$];
  string sq[$], sr[$];
  box bq[$], br[$];
  int nqq[$][$], nrr[$][$];
  int n0[$], n1[$], n2[$], nr0[$], nr1[$];
  box b0, b1, b2, r0, r1;

  function automatic int next_lo;
    lo_calls += 1;
    return 1;
  endfunction

  task check(string label, bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  initial begin
    iq = {1, 2, 3, 4};
    ir = {8, 9, 10};
    iq[next_lo():$] = ir;
    check("integral suffix", iq.size() == 4 && iq[0] == 1 &&
          iq[1] == 8 && iq[2] == 9 && iq[3] == 10);
    check("lower bound evaluated once", lo_calls == 1);

    vq = {8'h11, 8'h22, 8'h33};
    vr = {8'haa, 8'hbb};
    vq[1:$] = vr;
    check("packed vector suffix", vq.size() == 3 &&
          vq[0] == 8'h11 && vq[1] == 8'haa && vq[2] == 8'hbb);

    rq = {1.25, 2.5, 3.75};
    rr = {8.5, 9.5};
    rq[1:$] = rr;
    check("real suffix", rq.size() == 3 && rq[0] == 1.25 &&
          rq[1] == 8.5 && rq[2] == 9.5);

    sq = {"keep", "old-a", "old-b"};
    sr = {"new-a", "new-b"};
    sq[1:$] = sr;
    check("string suffix", sq.size() == 3 && sq[0] == "keep" &&
          sq[1] == "new-a" && sq[2] == "new-b");

    b0 = new(1); b1 = new(2); b2 = new(3);
    r0 = new(7); r1 = new(8);
    bq = {b0, b1, b2};
    br = {r0, r1};
    bq[1:$] = br;
    r0.value = 70;
    check("class handles stay shared", bq.size() == 3 &&
          bq[0].value == 1 && bq[1].value == 70 && bq[2].value == 8);

    n0 = {1}; n1 = {2}; n2 = {3};
    nr0 = {7, 8}; nr1 = {9};
    nqq.push_back(n0);
    nqq.push_back(n1);
    nqq.push_back(n2);
    nrr.push_back(nr0);
    nrr.push_back(nr1);
    nqq[1:$] = nrr;
    nrr[0].push_back(99);
    check("nested queues copy by value", nqq.size() == 3 &&
          nqq[0][0] == 1 && nqq[1].size() == 2 &&
          nqq[1][0] == 7 && nqq[1][1] == 8 && nqq[2][0] == 9);

    if (failed)
      $finish(1);
    $display("PASSED");
  end
endmodule
