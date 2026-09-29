class i2c_req_repro;
  rand bit [7:0] data_q[$];
endclass
class i2c_seq_repro;
  bit [7:0] data_q[$];
  i2c_req_repro req;
  task run();
    data_q.push_back(8'h27);
    data_q.push_back(8'hc3);
    req = new;
    if (!req.randomize() with {
      data_q.size() == local::data_q.size();
      foreach (data_q[i]) {
`ifdef SCALAR_LOCAL_ELEMENT
        data_q[i] == local::data_q[0];
`else
        data_q[i] == local::data_q[i];
`endif
      }
    }) $fatal(1, "randomize failed");
    if (req.data_q.size() != 2 || req.data_q[0] !== 8'h27 || req.data_q[1] !== 8'hc3)
      $fatal(1, "wrong queue copy %p", req.data_q);
    $display("PASS local queue index");
  endtask
endclass
module i2c_local_queue_index_repro;
  i2c_seq_repro seq;
  initial begin seq = new; seq.run(); end
endmodule
