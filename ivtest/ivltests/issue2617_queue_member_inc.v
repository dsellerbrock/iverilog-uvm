// IEEE 1800-2023 11.4.1, 11.4.2, 7.10: compound assignment and ++/-- on a
// packed member (a part select) of a queue or dynamic-array element.
module issue2617_queue_member_inc;
  typedef struct packed { logic [3:0] hi; logic [3:0] lo; } pk_t;
  pk_t pq[$];
  pk_t pd[];
  bit [7:0] bq[$];
  int i;
  initial begin
    pq.push_back('{4'h1, 4'h2});
    pq.push_back('{4'h7, 4'hf});
    ++pq[0].lo;                    $display("%h", pq[0]);
    pq[0].lo += 2;                 $display("%h", pq[0]);
    pq[1].lo++;                    $display("%h", pq[1]);   // wraps, hi unchanged
    i = 1; pq[i].hi -= 3;          $display("%h", pq[1]);
    pq[0].hi |= 4'h8;              $display("%h", pq[0]);
    pd = new[2]; pd[1] = '{4'h3, 4'h4};
    pd[1].lo *= 2;                 $display("%h", pd[1]);
    --pd[1].hi;                    $display("%h", pd[1]);
    bq.push_back(8'h0f);
    bq[0][7:4] += 1;               $display("%h", bq[0]);
  end
endmodule
