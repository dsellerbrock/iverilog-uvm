module test;
  bit [7:0] q[$];
  logic [7:0] four_state_q[$];
  bit [7:0] front_value;
  bit [7:0] back_value;

  initial begin
    front_value = q.pop_front();
    back_value = q.pop_back();
    if (front_value !== 8'h00 || back_value !== 8'h00 ||
        q.size() != 0 || q[3] !== 8'h00)
      $display("FAILED: two-state empty pop default");
    else
      $display("PASSED: two-state empty pop default");

    if (four_state_q.pop_front() !== 8'hxx ||
        four_state_q.pop_back() !== 8'hxx || four_state_q.size() != 0)
      $display("FAILED: four-state empty pop default");
    else
      $display("PASSED: four-state empty pop default");
  end
endmodule
