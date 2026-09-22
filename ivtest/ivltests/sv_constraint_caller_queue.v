/*
 * Caller-scope queues and dynamic arrays in inline foreach constraints.
 * IEEE 1800-2017 18.7, 18.5.8.1; IEEE 1800-2023 18.7, 18.5.7.1.
 */
class caller_queue_item;
  rand bit [7:0] data[$];
endclass

class caller_queue_owner;
  bit [7:0] data_q[$];

  task run;
    caller_queue_item req = new;
    data_q.push_back(8'h12);
    data_q.push_back(8'ha5);
    if (!req.randomize() with {
      data.size() == local::data_q.size();
      foreach (data_q[i]) data[i] == local::data_q[i];
    }) $fatal(1, "caller queue randomize failed");
    if (req.data.size() != 2 || req.data[0] != 8'h12 ||
        req.data[1] != 8'ha5) $fatal(1, "caller queue equality");
    $display("PASS caller queue foreach");
  endtask
endclass

class caller_darray_item;
  rand bit [7:0] data[$];
endclass

class caller_darray_owner;
  bit [7:0] data_q[];

  task run;
    caller_darray_item req = new;
    data_q = new[2];
    data_q[0] = 8'h12;
    data_q[1] = 8'ha5;
    if (!req.randomize() with {
      data.size() == local::data_q.size();
      foreach (data_q[i]) data[i] == data_q[i];
    }) $fatal(1, "caller dynamic array randomize failed");
    if (req.data.size() != 2 || req.data[0] != 8'h12 ||
        req.data[1] != 8'ha5) $fatal(1, "caller dynamic array equality");
    $display("PASS caller dynamic array foreach");
  endtask
endclass

module test;
  caller_queue_owner queue_owner;
  caller_darray_owner darray_owner;
  initial begin
    queue_owner = new;
    darray_owner = new;
    queue_owner.run;
    darray_owner.run;
  end
endmodule
