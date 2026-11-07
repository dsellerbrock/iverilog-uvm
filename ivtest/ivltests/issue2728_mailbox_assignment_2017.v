// IEEE 1800-2017 15.4.9 and 8.25: differently parameterized mailbox
// handles are different class types and are not assignment-compatible.
module issue2728_mailbox_assignment;
  mailbox untyped_mbx;
  mailbox #(int) typed_mbx;

  initial begin
    typed_mbx = new;
    untyped_mbx = typed_mbx;
  end
endmodule
