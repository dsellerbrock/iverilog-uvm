// IEEE 1800-2017 7.4.6 / 11.5.2: after selecting an unpacked-array
// word, every packed dimension of that word may still use a run-time
// integral index.
//
// The pure-packed form `p[row][bit]' already used the general packed
// offset path. The corresponding `a[word][row][bit]' form did not: the
// array-word path rejected a run-time nonfinal packed index and recovered
// by silently substituting row zero. Check values, not just compilation,
// so a dropped word index or incorrectly flattened packed offset fails.

module sv_unpacked_word_packed_multidim_var_index;

  typedef enum logic [2:0] {
    ENUM0 = 3'd0, ENUM1 = 3'd1, ENUM2 = 3'd2, ENUM3 = 3'd3
  } enum_t;

  localparam int unsigned PARAM_WORD = 1;
  localparam logic [5:0] FIXED_PATTERN = 6'b10_1101;
  localparam logic [5:0] PARAM_PATTERN = 6'b01_0011;

  // One unpacked dimension followed by two descending packed dimensions.
  logic [1:0][2:0] descending [PARAM_WORD:0];

  // The packed dimensions run in the opposite direction. This makes an
  // incorrect row*3+bit flattening visible in the whole-word check.
  logic [0:1][0:2] ascending [PARAM_WORD:0];

  // Two unpacked dimensions must both be consumed before the two packed
  // dimensions are collapsed. Use opposite unpacked range directions as
  // an additional word-address discriminator.
  logic [1:0][1:0] two_unpacked [1:0][0:1];

  // This suffix has a constant nonfinal packed index and a dynamic final
  // one. It must stay on the legacy constant-prefix path after the word
  // helper declines the general dynamic-prefix route; the unpacked word
  // must never be reconsidered as a packed index by that fallback.
  logic [1:0][2:0][3:0] mixed_suffix [1:0];

  // A computed exact element select must retain its declared enum type.
  enum_t [1:0][1:0] enum_words [1:0];
  enum_t enum_value;

  int unsigned errors;
  int unsigned u;
  int unsigned v;
  int unsigned row;
  int unsigned bit_idx;
  logic [5:0] pattern6;
  logic [3:0] pattern4;

  initial begin
    errors = 0;

    // Literal fixed word: both packed indices are run-time loop variables,
    // in both l-value and r-value position. Keep the other word at ones so
    // losing the unpacked word selection is observable.
    descending[0] = '0;
    descending[PARAM_WORD] = '1;
    for (row = 0; row < 2; row = row + 1)
      for (bit_idx = 0; bit_idx < 3; bit_idx = bit_idx + 1)
        descending[0][row][bit_idx] =
          FIXED_PATTERN[row*3 + bit_idx];

    for (row = 0; row < 2; row = row + 1)
      for (bit_idx = 0; bit_idx < 3; bit_idx = bit_idx + 1)
        if (descending[0][row][bit_idx] !==
            FIXED_PATTERN[row*3 + bit_idx]) begin
          $display("FAILED -- fixed word [%0d][%0d] = %b", row, bit_idx,
                   descending[0][row][bit_idx]);
          errors = errors + 1;
        end
    if (descending[0] !== FIXED_PATTERN ||
        descending[PARAM_WORD] !== 6'b11_1111) begin
      $display("FAILED -- fixed word flattening/value = %b, neighbour = %b",
               descending[0], descending[PARAM_WORD]);
      errors = errors + 1;
    end

    // A parameter expression selecting the unpacked word is the Caliptra
    // SRAM_LATENCY shape. Again, the packed row and bit remain dynamic.
    descending[0] = '0;
    descending[PARAM_WORD] = '0;
    for (row = 0; row < 2; row = row + 1)
      for (bit_idx = 0; bit_idx < 3; bit_idx = bit_idx + 1)
        descending[PARAM_WORD][row][bit_idx] =
          PARAM_PATTERN[row*3 + bit_idx];

    for (row = 0; row < 2; row = row + 1)
      for (bit_idx = 0; bit_idx < 3; bit_idx = bit_idx + 1)
        if (descending[PARAM_WORD][row][bit_idx] !==
            PARAM_PATTERN[row*3 + bit_idx]) begin
          $display("FAILED -- parameter word [%0d][%0d] = %b", row,
                   bit_idx, descending[PARAM_WORD][row][bit_idx]);
          errors = errors + 1;
        end
    if (descending[PARAM_WORD] !== PARAM_PATTERN ||
        descending[0] !== 6'b00_0000) begin
      $display("FAILED -- parameter word flattening/value = %b, neighbour = %b",
               descending[PARAM_WORD], descending[0]);
      errors = errors + 1;
    end

    // The unpacked word itself may also be selected at run time. Distinct
    // whole-word patterns make aliasing both words to word zero visible.
    for (u = 0; u < 2; u = u + 1) begin
      pattern6 = (u == 0) ? 6'b11_0001 : 6'b00_1110;
      for (row = 0; row < 2; row = row + 1)
        for (bit_idx = 0; bit_idx < 3; bit_idx = bit_idx + 1)
          descending[u][row][bit_idx] = pattern6[row*3 + bit_idx];

      for (row = 0; row < 2; row = row + 1)
        for (bit_idx = 0; bit_idx < 3; bit_idx = bit_idx + 1)
          if (descending[u][row][bit_idx] !==
              pattern6[row*3 + bit_idx]) begin
            $display("FAILED -- runtime word [%0d][%0d][%0d] = %b", u,
                     row, bit_idx, descending[u][row][bit_idx]);
            errors = errors + 1;
          end
      if (descending[u] !== pattern6) begin
        $display("FAILED -- runtime word %0d flattening/value = %b, want %b",
                 u, descending[u], pattern6);
        errors = errors + 1;
      end
    end

    // Ascending packed ranges reverse the canonical position of both row
    // and bit. Fill through dynamic indices and compare the packed word to
    // a known pattern, independently pinning direction normalization.
    for (u = 0; u < 2; u = u + 1) begin
      pattern6 = (u == 0) ? 6'b10_0110 : 6'b01_1001;
      for (row = 0; row < 2; row = row + 1)
        for (bit_idx = 0; bit_idx < 3; bit_idx = bit_idx + 1)
          ascending[u][row][bit_idx] =
            pattern6[(1-row)*3 + (2-bit_idx)];

      for (row = 0; row < 2; row = row + 1)
        for (bit_idx = 0; bit_idx < 3; bit_idx = bit_idx + 1)
          if (ascending[u][row][bit_idx] !==
              pattern6[(1-row)*3 + (2-bit_idx)]) begin
            $display("FAILED -- ascending [%0d][%0d][%0d] = %b", u,
                     row, bit_idx, ascending[u][row][bit_idx]);
            errors = errors + 1;
          end
      if (ascending[u] !== pattern6) begin
        $display("FAILED -- ascending word %0d = %b, want %b", u,
                 ascending[u], pattern6);
        errors = errors + 1;
      end
    end

    // Finally consume two run-time unpacked indices before collapsing the
    // two run-time packed indices. Each unpacked word receives a unique
    // packed value, detecting either an off-by-one split or a lost word.
    for (u = 0; u < 2; u = u + 1)
      for (v = 0; v < 2; v = v + 1) begin
        case (u*2 + v)
          0: pattern4 = 4'b0001;
          1: pattern4 = 4'b0110;
          2: pattern4 = 4'b1011;
          default: pattern4 = 4'b1100;
        endcase

        for (row = 0; row < 2; row = row + 1)
          for (bit_idx = 0; bit_idx < 2; bit_idx = bit_idx + 1)
            two_unpacked[u][v][row][bit_idx] =
              pattern4[row*2 + bit_idx];

        for (row = 0; row < 2; row = row + 1)
          for (bit_idx = 0; bit_idx < 2; bit_idx = bit_idx + 1)
            if (two_unpacked[u][v][row][bit_idx] !==
                pattern4[row*2 + bit_idx]) begin
              $display("FAILED -- two unpacked [%0d][%0d][%0d][%0d] = %b",
                       u, v, row, bit_idx,
                       two_unpacked[u][v][row][bit_idx]);
              errors = errors + 1;
            end
        if (two_unpacked[u][v] !== pattern4) begin
          $display("FAILED -- two unpacked word [%0d][%0d] = %b, want %b",
                   u, v, two_unpacked[u][v], pattern4);
          errors = errors + 1;
        end
      end

    mixed_suffix[0] = '0;
    mixed_suffix[1] = '0;
    for (u = 0; u < 2; u = u + 1)
      for (row = 0; row < 3; row = row + 1) begin
        pattern4 = (u == 0) ? (4'h1 + row) : (4'h8 + row);
        mixed_suffix[u][1][row] = pattern4;
      end
    for (u = 0; u < 2; u = u + 1)
      for (row = 0; row < 3; row = row + 1) begin
        pattern4 = (u == 0) ? (4'h1 + row) : (4'h8 + row);
        if (mixed_suffix[u][1][row] !== pattern4) begin
          $display("FAILED -- mixed suffix [%0d][1][%0d] = %h, want %h",
                   u, row, mixed_suffix[u][1][row], pattern4);
          errors = errors + 1;
        end
      end
    if (mixed_suffix[0][1] !== 12'h321 ||
        mixed_suffix[1][1] !== 12'ha98 ||
        mixed_suffix[0][0] !== '0 || mixed_suffix[1][0] !== '0) begin
      $display("FAILED -- mixed suffix values=%h/%h siblings=%h/%h",
               mixed_suffix[0][1], mixed_suffix[1][1],
               mixed_suffix[0][0], mixed_suffix[1][0]);
      errors = errors + 1;
    end

    for (u = 0; u < 2; u = u + 1)
      for (row = 0; row < 2; row = row + 1)
        for (bit_idx = 0; bit_idx < 2; bit_idx = bit_idx + 1) begin
          case (u*2 + row + bit_idx)
            0: enum_value = ENUM0;
            1: enum_value = ENUM1;
            2: enum_value = ENUM2;
            default: enum_value = ENUM3;
          endcase
          enum_words[u][row][bit_idx] = enum_value;
          enum_value = enum_words[u][row][bit_idx];
          case (u*2 + row + bit_idx)
            0: if (enum_value != ENUM0) errors = errors + 1;
            1: if (enum_value != ENUM1) errors = errors + 1;
            2: if (enum_value != ENUM2) errors = errors + 1;
            default: if (enum_value != ENUM3) errors = errors + 1;
          endcase
        end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED -- %0d total errors", errors);
    $finish;
  end

endmodule
