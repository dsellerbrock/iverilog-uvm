class holder;
  int signed_q[2][$];
  int unsigned unsigned_q[2][$];
endclass
module issue3185_signed_queue;
  initial begin
    automatic holder h = new;
    h.signed_q[1].push_back(-5);
    h.signed_q[1].push_back(32'h80000000);
    h.signed_q[1].push_back(17);
    h.unsigned_q[0].push_back(32'hfffffffb);
    $display("%p", h.signed_q);
    $display("%p", h.unsigned_q);
  end
endmodule
