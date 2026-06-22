// Regression: `[$]` last-element select used as an l-value on queues, e.g.
//   xfer.data_ack_q[$] = v;        // last element of a queue class property
//   txn[$].data_ack_q[$] = v;      // queue l-value root + nested last element
// (OpenTitan i2c_base_vseq.sv). These were rejected with
//   "sorry: Last-element select of dynamic/queue class ... is not supported."
// The last-element index is now computed as <queue>.size()-1 (reusing
// make_last_array_index_expr_) for the l-value root, the queue class property,
// and the object-access cases -- including when the owning object is itself an
// indexed queue element (txn[$].data_ack_q[$]).
class pkt;
  bit [7:0] data_ack_q[$];
endclass
module top;
  pkt a, b;
  pkt txn[$];
  int errors = 0;
  initial begin
    a = new();
    a.data_ack_q.push_back(8'h00);
    a.data_ack_q.push_back(8'h00);
    a.data_ack_q[$] = 8'hAB;              // property last-element write
    if (a.data_ack_q[1] != 8'hAB) errors++;

    b = new();
    b.data_ack_q.push_back(8'h00);
    txn.push_back(a);
    txn.push_back(b);                     // txn[$] == b
    txn[$].data_ack_q[$] = 8'hCD;         // l-value root + nested last-element
    if (b.data_ack_q[0] != 8'hCD) errors++;
    if (a.data_ack_q[1] != 8'hAB) errors++;   // unchanged

    if (errors == 0) $display("PASS");
    else $display("FAIL (%0d errors)", errors);
  end
endmodule
