/*
 * Empty/resized caller queues and failed-solve rollback.
 */
class caller_queue_rollback_item;
  rand bit [7:0] data[$];
endclass

class caller_queue_resize_owner;
  bit [7:0] data_q[$];

  task run;
    caller_queue_rollback_item req = new;
    if (!req.randomize() with {
      data.size() == local::data_q.size();
      foreach (data_q[i]) data[i] == local::data_q[i];
    }) $fatal(1, "empty randomize");
    if (req.data.size() != 0) $fatal(1, "empty size");
    data_q.push_back(8'h12);
    data_q.push_back(8'ha5);
    data_q.push_back(8'h7e);
    if (!req.randomize() with {
      data.size() == local::data_q.size();
      foreach (data_q[i]) data[i] == local::data_q[i];
    }) $fatal(1, "resized randomize");
    if (req.data.size() != 3 || req.data[0] != 8'h12 ||
        req.data[1] != 8'ha5 || req.data[2] != 8'h7e)
      $fatal(1, "resized value");
    $display("PASS caller queue empty resize");
  endtask
endclass

class caller_queue_unsat_item;
  rand bit [7:0] data[$];
endclass

class caller_queue_unsat_owner;
  bit [7:0] data_q[$];

  task run;
    caller_queue_unsat_item req = new;
    req.data.push_back(8'h3c);
    data_q.push_back(8'h12);
    if (req.randomize() with {
      data.size() == local::data_q.size();
      foreach (data_q[i]) data[i] == local::data_q[i];
      data[0] == 8'haa;
    }) $fatal(1, "unexpected SAT");
    if (req.data.size() != 1 || req.data[0] != 8'h3c)
      $fatal(1, "rollback");
    $display("PASS caller queue unsat rollback");
  endtask
endclass

class caller_queue_wide_item;
  rand bit [63:0] data[$];
endclass

class caller_queue_wide_owner;
  logic [63:0] q[$];

  task copy(caller_queue_wide_item req);
    if (!req.randomize() with {
      data.size() == local::q.size();
      foreach (q[i]) data[i] == local::q[i];
    }) $fatal(1, "wide copy failed");
    if (req.data.size() != q.size()) $fatal(1, "wide size");
    foreach (q[i])
      if (req.data[i] !== q[i]) $fatal(1, "wide value");
  endtask

  task run;
    caller_queue_wide_item req = new;
    q.push_back(64'h8000000000000000);
    q.push_back(64'hffffffffffffffff);
    copy(req);
    if (q.size() != 2 || q[0] !== 64'h8000000000000000 ||
        q[1] !== 64'hffffffffffffffff) $fatal(1, "caller mutation");
    q.delete();
    copy(req);
    q.push_back(64'h0000000100000000);
    copy(req);
    if (!req.randomize() with {
      data.size() == 1;
      foreach (q[i])
        if (i < 0) data[i] == local::q[i+10];
      data[0] == 64'hfedcba9876543210;
    }) $fatal(1, "guarded invalid read");
    if (req.data[0] !== 64'hfedcba9876543210)
      $fatal(1, "guarded result");
    $display("PASS wide resize guard");
  endtask
endclass

module test;
  caller_queue_resize_owner resize_owner;
  caller_queue_unsat_owner unsat_owner;
  caller_queue_wide_owner wide_owner;
  initial begin
    resize_owner = new;
    unsat_owner = new;
    wide_owner = new;
    resize_owner.run;
    unsat_owner.run;
    wide_owner.run;
  end
endmodule
