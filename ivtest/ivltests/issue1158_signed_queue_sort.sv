module issue1158_signed_queue_sort;
  int signed sq[$];
  logic [15:0] words[];
  logic [7:0] four_state[$];
  bit [7:0] two_state[$];
  int calls = 0;

  function automatic int next_value();
    calls++;
    return 7;
  endfunction

  initial begin
    sq = {3, -2, 0, -7};
    if (sq.size() != 4 || sq[0] !== 3 || sq[1] !== -2 ||
        sq[2] !== 0 || sq[3] !== -7)
      $fatal(1, "unsized operands before sort: %p", sq);
    sq.sort();
    if (sq.size() != 4 || sq[0] !== -7 || sq[1] !== -2 ||
        sq[2] !== 0 || sq[3] !== 3)
      $fatal(1, "unsized operands after sort: %p", sq);

    sq = {3, -32'sd2, 0, -32'sd7};
    if (sq.size() != 4 || sq[0] !== 3 || sq[1] !== -2 ||
        sq[2] !== 0 || sq[3] !== -7)
      $fatal(1, "sized operands before sort: %p", sq);

    sq = {-next_value(), 8'sd3 - 8'sd5};
    if (calls != 1 || sq.size() != 2 || sq[0] !== -7 || sq[1] !== -2)
      $fatal(1, "runtime and binary operands: %p, calls=%0d", sq, calls);

    words = {-8'sh80, -8'd2, 8'd255 + 8'd2};
    if (words.size() != 3 || words[0] !== 16'hff80 ||
        words[1] !== 16'h00fe || words[2] !== 16'h0001)
      $fatal(1, "dynamic array operand sizing: %p", words);

    four_state = {~4'b0x01};
    two_state = {~4'b0x01};
    if (four_state[0] !== 8'b0000_1x10 || two_state[0] !== 8'h0a)
      $fatal(1, "state conversion: %b, %b", four_state[0], two_state[0]);

    $display("PASSED");
  end
endmodule
