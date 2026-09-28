module tb;
  localparam int MAX_NUM_ENDPOINTS = 7;
  bit [MAX_NUM_ENDPOINTS-1:0] ep_requests;

  covergroup edn_endpoints_cg @(ep_requests);
    cp_ep_requests: coverpoint ep_requests {
      bins none = { $countones(ep_requests) == 0 };
      bins some = { $countones(ep_requests) inside {[1:MAX_NUM_ENDPOINTS-1]} };
      bins all = { $countones(ep_requests) == MAX_NUM_ENDPOINTS };
    }
  endgroup
  edn_endpoints_cg cg = new;
endmodule
