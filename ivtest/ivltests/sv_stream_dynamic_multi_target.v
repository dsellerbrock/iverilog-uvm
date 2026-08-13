// IEEE 1800-2017 11.4.14.4: a streaming assignment target may mix
// fixed-size and dynamically sized members. The first dynamic member in
// source order greedily consumes the stream remainder after ALL fixed widths
// are reserved; later dynamic members become empty.
module test;
  int errors = 0;
  int calls = 0;

  function automatic logic [39:0] make_stream();
    calls += 1;
    return 40'h10_20_30_40_50;
  endfunction

  task automatic check(input bit ok, input string what);
    if (!ok) begin
      errors += 1;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    byte left;
    byte right_da[];
    logic [15:0] right;
    byte first[];
    byte later[];
    byte marker;
    byte q[$];
    byte bounded[$:1];
    string text;
    int header;
    int length;
    int crc;
    byte payload[];

    // Exact sv-tests/UVM-shaped case: fixed header fields precede a dynamic
    // payload at the right edge of the target.
    {<<8{header, length, crc, payload}} =
        {<<8{32'd12, 32'd5, 32'd42, 8'h01, 8'h02, 8'h03}};
    check(header == 12 && length == 5 && crc == 42,
          "sv-tests fixed header fields");
    check(payload.size() == 3 && payload[0] == 8'h01
          && payload[1] == 8'h02 && payload[2] == 8'h03,
          "sv-tests dynamic payload");
    payload = new[1];
    payload[0] = 8'hFF;
    {>>{right, payload}} = 16'hCDEF;
    check(right == 16'hCDEF && payload.size() == 0,
          "zero-width greedy remainder clears old value");

    // Fixed fields on both sides of the greedy dynamic member.
    {>>{left, right_da, right}} = 48'hA1_B2_C3_D4_E5_F6;
    check(left == 8'hA1, "left fixed field");
    check(right == 16'hE5F6, "right fixed field");
    check(right_da.size() == 3 && right_da[0] == 8'hB2
          && right_da[1] == 8'hC3 && right_da[2] == 8'hD4,
          "middle dynamic-array remainder");

    // First dynamic target gets the remainder; the later one is empty.
    later = new[2];
    later[0] = 8'hEE;
    later[1] = 8'hFF;
    {>>{first, marker, later}} = 40'h11_22_33_44_55;
    check(first.size() == 4 && first[0] == 8'h11
          && first[1] == 8'h22 && first[2] == 8'h33
          && first[3] == 8'h44, "leftmost dynamic target is greedy");
    check(marker == 8'h55, "fixed field after greedy target");
    check(later.size() == 0, "later dynamic target is empty");

    // The inverse <<8 operation reverses byte blocks before distribution.
    {<<8{left, q, right}} = 48'hA1_B2_C3_D4_E5_F6;
    check(left == 8'hF6 && right == 16'hB2A1,
          "left-stream block reversal fixed fields");
    check(q.size() == 3 && q[0] == 8'hE5 && q[1] == 8'hD4
          && q[2] == 8'hC3, "left-stream queue remainder");

    // Whole source expression is evaluated once before any target changes.
    {>>{right_da, marker}} = make_stream();
    check(calls == 1, "stream source evaluated exactly once");
    check(right_da.size() == 4 && right_da[0] == 8'h10
          && right_da[1] == 8'h20 && right_da[2] == 8'h30
          && right_da[3] == 8'h40 && marker == 8'h50,
          "function-result stream distribution");

    // String and bounded-queue destinations use their declared whole-value
    // store rules after greedy sizing.
    {>>{text, marker}} = 40'h41_42_43_44_5A;
    check(text == "ABCD" && marker == 8'h5A,
          "string greedy target");
    {>>{bounded}} = 24'hDE_AD_BE;
    check(bounded.size() == 2 && bounded[0] == 8'hDE
          && bounded[1] == 8'hAD, "bounded queue truncation");

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED: %0d checks", errors);
  end
endmodule
