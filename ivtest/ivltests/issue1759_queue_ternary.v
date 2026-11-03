module issue1759_queue_ternary;
  typedef struct { int value; } record_t;
  class token;
    int value;
  endclass

  int q0[$] = '{1, 4, 3};
  int q1[$] = '{1, 5, 3};
  int qshort[$] = '{1, 2};
  int result[$];
  bit [3:0] bq0[$] = '{4'hc};
  bit [3:0] bq1[$] = '{4'hd};
  bit [3:0] bresult[$];
  integer iq0[$] = '{4};
  integer iq1[$] = '{5};
  integer iresult[$];
  real rq0[$] = '{1.5};
  real rq1[$] = '{2.5};
  real rresult[$];
  string sq0[$] = '{"left"};
  string sq1[$] = '{"right"};
  string sresult[$];
  record_t st0[$] = '{'{4}};
  record_t st1[$] = '{'{5}};
  record_t stresult[$];
  token h0, h1;
  token cq0[$], cq1[$], cresult[$];
  int nq0[$][$] = '{'{4, 8}};
  int nq1[$][$] = '{'{4, 9}};
  int nresult[$][$];
  logic condition = 1'bx;

  initial begin
    result = condition ? q0 : q1;
    if (result.size() != 3 || result[0] !== 1
        || result[1] !== 0 || result[2] !== 3)
      $fatal(1, "2-state queue merge failed: %p", result);

    condition = 1'bz;
    result = condition ? q0 : q1;
    if (result.size() != 3 || result[1] !== 0)
      $fatal(1, "high-impedance queue merge failed: %p", result);

    result = condition ? q0 : qshort;
    if (result.size() != 0)
      $fatal(1, "queue size mismatch did not produce an empty queue: %p",
             result);

    condition = 1'b1;
    result = condition ? q0 : q1;
    if (result.size() != 3 || result[1] !== 4)
      $fatal(1, "true queue selection failed: %p", result);
    condition = 1'b0;
    result = condition ? q0 : q1;
    if (result.size() != 3 || result[1] !== 5)
      $fatal(1, "false queue selection failed: %p", result);

    condition = 1'bx;
    bresult = condition ? bq0 : bq1;
    if (bresult.size() != 1 || bresult[0] !== 4'b0000)
      $fatal(1, "2-state packed element default failed: %p", bresult);

    iresult = condition ? iq0 : iq1;
    if (iresult.size() != 1 || iresult[0] !== 32'hxxxx_xxxx)
      $fatal(1, "4-state integral element default failed: %p", iresult);

    rresult = condition ? rq0 : rq1;
    if (rresult.size() != 1 || rresult[0] != 0.0)
      $fatal(1, "real element default failed: %p", rresult);

    sresult = condition ? sq0 : sq1;
    if (sresult.size() != 1 || sresult[0] != "")
      $fatal(1, "string element default failed: %p", sresult);

    stresult = condition ? st0 : st1;
    if (stresult.size() != 1 || stresult[0].value !== 0)
      $fatal(1, "unpacked struct element default failed: %p", stresult);

    h0 = new;
    h1 = new;
    cq0.push_back(h0);
    cq1.push_back(h1);
    cresult = condition ? cq0 : cq1;
    if (cresult.size() != 1 || cresult[0] !== null)
      $fatal(1, "class-handle element default failed: %p", cresult);

    nresult = condition ? nq0 : nq1;
    if (nresult.size() != 1 || nresult[0].size() != 0)
      $fatal(1, "nested queue element default failed: %p", nresult);

    $display("PASSED");
  end
endmodule
