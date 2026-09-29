class i2c_req_original_repro;
  bit [7:0] data_q[$];
  rand bit [7:0] fbyte;
  constraint fbyte_c { fbyte inside {[0:127]}; }
endclass
class i2c_seq_original_repro;
  bit [7:0] data_q[$];
  i2c_req_original_repro req;
  task run();
    data_q.push_back(8'h27);
    data_q.push_back(8'hc3);
    req = new;
    if (req.randomize() with {
      data_q.size() == local::data_q.size();
      foreach (data_q[i]) data_q[i] == local::data_q[i];
    }) $fatal(1, "non-rand payload constraint incorrectly succeeded");
    if (req.data_q.size() != 0)
      $fatal(1, "failed randomize mutated non-rand payload");
    $display("PASS original non-rand constraint fails");
  endtask
endclass
module i2c_nonrand_original_failure_repro;
  i2c_seq_original_repro seq;
  initial begin seq = new; seq.run(); end
endmodule
