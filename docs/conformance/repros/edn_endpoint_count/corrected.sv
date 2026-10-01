module tb;
  localparam int MAX_NUM_ENDPOINTS = 7;
  bit [MAX_NUM_ENDPOINTS-1:0] ep_requests;

  covergroup edn_endpoints_cg @(ep_requests);
    cp_ep_requests: coverpoint $countones(ep_requests) {
      bins none = {0};
      bins some = {[1:MAX_NUM_ENDPOINTS-1]};
      bins all = {MAX_NUM_ENDPOINTS};
    }
  endgroup
  edn_endpoints_cg cg = new;

  initial begin
    #1 ep_requests = 7'b0000101;
    #1 ep_requests = '0;
    #1 ep_requests = '1;
    #1 if (cg.get_coverage() != 100.0)
         $fatal(1, "endpoint count coverage %0f", cg.get_coverage());
    $display("PASS endpoint count coverage %0f", cg.get_coverage());
    $finish;
  end
endmodule
