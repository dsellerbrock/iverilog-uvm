/*
 * Scalar signed state values, X rollback, and target-first lookup.
 */
class caller_queue_signed_item;
  rand bit signed [7:0] data[$];
endclass

class caller_queue_signed_owner;
  logic signed [7:0] source_q[$];

  task run;
    caller_queue_signed_item req = new;
    source_q.push_back(-128);
    source_q.push_back(127);
    if (!req.randomize() with {
      data.size() == local::source_q.size();
      foreach (source_q[i]) data[i] == local::source_q[i];
    }) $fatal(1, "signed solve");
    if (req.data.size() != 2 || req.data[0] != -128 || req.data[1] != 127)
      $fatal(1, "signed endpoints");

    source_q[0] = 8'hxx;
    if (req.randomize() with {
      data.size() == local::source_q.size();
      foreach (source_q[i]) data[i] == local::source_q[i];
    }) $fatal(1, "X accepted");
    if (req.data.size() != 2 || req.data[0] != -128 || req.data[1] != 127 ||
        source_q[0] !== 8'hxx) $fatal(1, "failed solve mutation");
    $display("PASS signed caller and X rollback");
  endtask
endclass

class caller_queue_collision_item;
  rand bit [7:0] data_q[$];
  constraint size_c { data_q.size() == 1; }
endclass

class caller_queue_collision_owner;
  bit [7:0] data_q[$];

  task run;
    caller_queue_collision_item req = new;
    data_q.push_back(8'h12);
    data_q.push_back(8'ha5);
    if (!req.randomize() with {
      foreach (data_q[i]) i == 0;
      data_q[0] == local::data_q[0];
    }) $fatal(1, "target-first lookup");
    if (req.data_q.size() != 1 || req.data_q[0] != 8'h12 ||
        data_q.size() != 2 || data_q[1] != 8'ha5)
      $fatal(1, "copy/preservation");
    $display("PASS target-first collision");
  endtask
endclass

class caller_queue_oob_item;
  rand bit [7:0] data[$];
endclass

class caller_queue_oob_owner;
  bit [7:0] data_q[$];

  task run;
    caller_queue_oob_item req = new;
    data_q.push_back(8'h12);
    data_q.push_back(8'ha5);
    req.data.push_back(8'h77);
    if (req.randomize() with {
      data.size() == local::data_q.size();
      foreach (data_q[i]) data[i] == local::data_q[i+1];
    }) $fatal(1, "out of bounds accepted");
    if (req.data.size() != 1 || req.data[0] != 8'h77)
      $fatal(1, "out of bounds rollback");
    $display("PASS caller queue out of bounds rollback");
  endtask
endclass

module test;
  caller_queue_signed_owner signed_owner;
  caller_queue_collision_owner collision_owner;
  caller_queue_oob_owner oob_owner;
  initial begin
    signed_owner = new;
    collision_owner = new;
    oob_owner = new;
    signed_owner.run;
    collision_owner.run;
    oob_owner.run;
  end
endmodule
