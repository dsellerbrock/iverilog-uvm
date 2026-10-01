class i2c_req_payload_repro;
  bit [7:0] data_q[$];
  int num_data;
  rand bit [7:0] fbyte;
  constraint fbyte_c { fbyte inside {[0:127]}; }
endclass
module i2c_nonrand_payload_copy_repro;
  initial begin
    bit [7:0] source_q[$];
    i2c_req_payload_repro req;
    req = new;
    source_q.push_back(8'h27);
    source_q.push_back(8'hc3);
    if (req.randomize() with { data_q.size() == 2; })
      $fatal(1, "non-rand empty payload incorrectly solved");
    if (req.data_q.size() != 0)
      $fatal(1, "failed randomize mutated payload");
    req.data_q = source_q;
    req.num_data = source_q.size();
    if (!req.randomize())
      $fatal(1, "randomize of real rand fields failed");
    if (req.num_data != 2 || req.data_q.size() != 2 ||
        req.data_q[0] !== 8'h27 || req.data_q[1] !== 8'hc3 ||
        req.fbyte > 127)
      $fatal(1, "payload copy or fbyte constraint failed");
    $display("PASS non-rand payload copy");
  end
endmodule
