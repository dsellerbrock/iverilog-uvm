// Regression: a fixed unpacked array whose element is a queue, e.g.
//   typedef bit [7:0] data_q[$];
//   data_q response_mem[2**Addr7BitMode];   // OpenTitan i2c_device_response_seq
//   bit [7:0] mem[N][$];                     // inline form
// Previously rejected ("sorry: array of queue type is not yet supported").
//
// Such a fixed array of queues is lowered to an integer-keyed associative array
// of the queue (see elaborate_static_array_type), reusing the assoc-of-queue
// machinery. OpenTitan DV uses these purely index-and-use plus foreach
// (push_back/.size/.pop_front/foreach-delete), for which an associative array
// is behaviorally equivalent. This is a documented pragmatic lowering, not a
// dense fixed array (foreach visits only touched indices).
module top;
  typedef bit [7:0] data_q[$];
  data_q mem[2**4];           // form A: array of a queue typedef
  bit [7:0] inl[4][$];        // form B: inline array-of-queue
  int errors = 0;
  initial begin
    // form A
    mem[5].push_back(8'hAA);
    mem[5].push_back(8'hBB);
    mem[8].push_back(8'h11);
    if (mem[5].size() != 2)     errors++;
    if (mem[5][0] != 8'hAA)     errors++;
    if (mem[5][1] != 8'hBB)     errors++;
    if (mem[8].size() != 1)     errors++;
    if (mem[5].pop_front() != 8'hAA) errors++;
    if (mem[5].size() != 1)     errors++;
    // foreach visits touched indices (used by OT for cleanup)
    foreach (mem[i]) mem[i].delete();
    if (mem[5].size() != 0)     errors++;
    // form B
    inl[2].push_back(8'h77);
    if (inl[2].size() != 1 || inl[2][0] != 8'h77) errors++;
    if (errors == 0) $display("PASS");
    else $display("FAIL (%0d errors)", errors);
  end
endmodule
