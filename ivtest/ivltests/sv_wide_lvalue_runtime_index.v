// IEEE 1800-2023 11.5.1: a packed write with a wholly out-of-bounds
// index has no effect, while a partially out-of-bounds write changes only
// the in-range bits. Exercise the run-time offset carriers used by packed
// vectors, unpacked-array words, associative-array elements, class-array
// elements, nonblocking assignments, and string character writes. In
// particular, no 65-bit index may alias bit/word zero or size a temporary
// vector from the numeric value of the index.
module sv_wide_lvalue_runtime_index;
  class C;
    logic [15:0] words[2];
  endclass

  logic [15:0] words[2];
  logic [15:0] assoc[string];
  logic [64:0] word_index;
  logic [64:0] unsigned_part_index;
  logic signed [64:0] signed_part_index;
  string text;
  int errors;

  initial begin
    automatic C obj = new;

    unsigned_part_index = 65'h1_0000_0000_0000_0000;
    signed_part_index = -65'sd1;

    // Static and dynamic unpacked-word addresses with dynamic packed parts.
    words[0] = 16'h1234;
    words[0][unsigned_part_index +: 4] ^= 4'hf;
    if (words[0] !== 16'h1234) begin
      $display("FAILED static word huge part=%h", words[0]); errors++;
    end

    word_index = 0;
    words[word_index][unsigned_part_index +: 4] ^= 4'hf;
    if (words[0] !== 16'h1234) begin
      $display("FAILED dynamic word huge part=%h", words[0]); errors++;
    end

    word_index = 65'h0_0000_0001_0000_0000;
    unsigned_part_index = 0;
    words[word_index][unsigned_part_index +: 4] ^= 4'hf;
    if (words[0] !== 16'h1234) begin
      $display("FAILED huge word alias=%h", words[0]); errors++;
    end

    // The same large address must remain a no-op through an NBA event.
    words[word_index][3:0] <= 4'hf;
    #1;
    if (words[0] !== 16'h1234) begin
      $display("FAILED huge NBA word alias=%h", words[0]); errors++;
    end

    // Fixed-width container-element RMW paths must clip instead of growing.
    unsigned_part_index = 65'h1_0000_0000_0000_0000;
    assoc["a"] = 16'h1234;
    assoc["a"][unsigned_part_index +: 4] = 4'hf;
    if (assoc["a"] !== 16'h1234) begin
      $display("FAILED assoc huge part=%h", assoc["a"]); errors++;
    end
    assoc["a"] = 16'h0000;
    assoc["a"][signed_part_index +: 4] = 4'ha;
    if (assoc["a"] !== 16'h0005) begin
      $display("FAILED assoc negative clip=%h", assoc["a"]); errors++;
    end

    obj.words[0] = 16'h1234;
    obj.words[0][unsigned_part_index +: 4] = 4'hf;
    if (obj.words[0] !== 16'h1234) begin
      $display("FAILED property huge part=%h", obj.words[0]); errors++;
    end
    obj.words[0] = 16'h0000;
    obj.words[0][signed_part_index +: 4] = 4'ha;
    if (obj.words[0] !== 16'h0005) begin
      $display("FAILED property negative clip=%h", obj.words[0]); errors++;
    end

    text = "ab";
    word_index = 65'h0_0000_0001_0000_0000;
    text[word_index] = "Z";
    if (text != "ab") begin
      $display("FAILED string huge character=%s", text); errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
