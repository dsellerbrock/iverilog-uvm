// IEEE 1800-2017/2023 7.4.6, 7.6: a fixed unpacked-array slice remains
// an unpacked value, with its elements copied to a queue left to right.
class holder_t;
  bit [7:0] descending[8:1];
  bit [7:0] ascending[-1:3];

  task run;
    bit [7:0] q[$];
    logic [7:0] four_state_q[$];
    foreach (descending[i]) descending[i] = i;
    foreach (ascending[i]) ascending[i] = i + 2;

    q = descending[6:4];
    if (q.size() != 3 || q[0] != 6 || q[1] != 5 || q[2] != 4)
      $fatal(1, "descending property slice order");
    four_state_q = descending[6:4];
    if (four_state_q.size() != 3 || four_state_q[0] != 6
        || four_state_q[1] != 5 || four_state_q[2] != 4)
      $fatal(1, "two-state to four-state element copy");

    q = descending[4 +: 3];
    if (q.size() != 3 || q[0] != 6 || q[1] != 5 || q[2] != 4)
      $fatal(1, "descending indexed slice order");
    q = descending[6 -: 3];
    if (q.size() != 3 || q[0] != 6 || q[1] != 5 || q[2] != 4)
      $fatal(1, "descending downward indexed slice order");

    q = ascending[-1:1];
    if (q.size() != 3 || q[0] != 1 || q[1] != 2 || q[2] != 3)
      $fatal(1, "ascending property slice order");
    q = ascending[-1 +: 3];
    if (q.size() != 3 || q[0] != 1 || q[1] != 2 || q[2] != 3)
      $fatal(1, "ascending indexed slice order");
    q = descending[6:6];
    if (q.size() != 1 || q[0] != 6)
      $fatal(1, "single-element slice");

    q = descending[6:4];
    descending[6] = 99;
    if (q[0] != 6) $fatal(1, "source mutation changed queue copy");
    q[1] = 88;
    if (descending[5] != 5)
      $fatal(1, "queue mutation changed source array");
    descending[6] = 6;

    q = descending;
    if (q.size() != 8 || q[0] != 8 || q[7] != 1)
      $fatal(1, "whole-array to queue control");
    q = '{8'd9, 8'd7, 8'd5};
    if (q.size() != 3 || q[0] != 9 || q[2] != 5)
      $fatal(1, "assignment-pattern to queue control");
  endtask
endclass

module test;
  bit [7:0] direct_array[8:1];
  bit [7:0] q[$];
  holder_t holder;
  initial begin
    holder = new;
    holder.run();
    foreach (direct_array[i]) direct_array[i] = i;
    q = direct_array[6:4];
    if (q.size() != 3 || q[0] != 6 || q[1] != 5 || q[2] != 4)
      $fatal(1, "direct signal slice order");
    q = holder.descending[6:4];
    if (q.size() != 3 || q[0] != 6 || q[1] != 5 || q[2] != 4)
      $fatal(1, "explicit class-handle property slice order");
    $display("PASSED");
  end
endmodule
