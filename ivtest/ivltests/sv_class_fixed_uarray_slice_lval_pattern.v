// Fixed unpacked-array slices of class properties are aggregate l-values.
// Cover the OpenTitan DMA digest writes plus direction, indexed-range,
// nonzero-bound, type, and RHS-snapshot semantics.
module test;
  class holder_t;
    bit [31:0] exp_digest[16];
    bit [31:0] exp_digest_short[16];
    logic [7:0] descending[7:0];
    logic [7:0] indexed_desc_plus[7:0];
    logic [7:0] indexed_desc_minus[7:0];
    logic [7:0] shifted[-2:3];
    logic [7:0] indexed_down[0:5];
    logic [7:0] overlap[0:3];
    logic [7:0] single[0:2];
    real real_values[0:3];
    string string_values[3:0];

    function void seed();
      foreach (exp_digest[i]) exp_digest[i] = 32'h1000 + i;
      foreach (exp_digest_short[i]) exp_digest_short[i] = 32'h2000 + i;
      foreach (descending[i]) descending[i] = 8'hd0 + i;
      foreach (indexed_desc_plus[i]) indexed_desc_plus[i] = 8'h80 + i;
      foreach (indexed_desc_minus[i]) indexed_desc_minus[i] = 8'h90 + i;
      foreach (shifted[i]) shifted[i] = 8'he0 + i + 2;
      foreach (indexed_down[i]) indexed_down[i] = 8'hc0 + i;
      foreach (overlap[i]) overlap[i] = i + 1;
      foreach (single[i]) single[i] = 8'h60 + i;
      foreach (real_values[i]) real_values[i] = i;
      foreach (string_values[i]) string_values[i] = "old";
    endfunction

    function void apply();
      exp_digest[8:15] = '{default: 0};
      exp_digest_short[12:15] = '{default: 0};
      descending[5:3] = '{8'h55, 8'h44, 8'h33};
      indexed_desc_plus[2 +: 3] = '{8'ha4, 8'ha3, 8'ha2};
      indexed_desc_minus[5 -: 3] = '{8'hb5, 8'hb4, 8'hb3};
      shifted[-1 +: 3] = '{8'ha1, 8'ha2, 8'ha3};
      indexed_down[4 -: 2] = '{8'hb3, 8'hb4};
      single[0:0] = '{8'h5a};

      // The complete RHS must be captured before any destination word is
      // written. This swaps the selected property words.
      overlap[1:2] = '{overlap[2], overlap[1]};

      real_values[1:2] = '{1.25, 2.5};
      string_values[2:1] = '{"two", "one"};
    endfunction
  endclass

  holder_t holders[0:1];
  int receiver_calls;
  int rhs_calls;

  function automatic int receiver_index();
    receiver_calls++;
    return 1;
  endfunction

  function automatic logic [7:0] rhs_value(input int index);
    rhs_calls++;
    return holders[1].overlap[index];
  endfunction

  task automatic check(input bit ok, input string what);
    if (!ok) begin
      $display("FAILED: %s", what);
      $finish(1);
    end
  endtask

  initial begin
    holder_t holder;

    holder = new;
    holder.seed();
    holder.apply();

    for (int i = 0; i < 8; i++)
      check(holder.exp_digest[i] == 32'h1000 + i,
            $sformatf("digest prefix %0d", i));
    for (int i = 8; i < 16; i++)
      check(holder.exp_digest[i] == 0, $sformatf("digest tail %0d", i));
    for (int i = 0; i < 12; i++)
      check(holder.exp_digest_short[i] == 32'h2000 + i,
            $sformatf("short digest prefix %0d", i));
    for (int i = 12; i < 16; i++)
      check(holder.exp_digest_short[i] == 0,
            $sformatf("short digest tail %0d", i));

    check(holder.descending[5] == 8'h55
          && holder.descending[4] == 8'h44
          && holder.descending[3] == 8'h33,
          "descending positional pattern");
    check(holder.indexed_desc_plus[4] == 8'ha4
          && holder.indexed_desc_plus[3] == 8'ha3
          && holder.indexed_desc_plus[2] == 8'ha2
          && holder.indexed_desc_plus[5] == 8'h85
          && holder.indexed_desc_plus[1] == 8'h81,
          "descending declaration indexed plus slice");
    check(holder.indexed_desc_minus[5] == 8'hb5
          && holder.indexed_desc_minus[4] == 8'hb4
          && holder.indexed_desc_minus[3] == 8'hb3
          && holder.indexed_desc_minus[6] == 8'h96
          && holder.indexed_desc_minus[2] == 8'h92,
          "descending declaration indexed minus slice");
    check(holder.shifted[-1] == 8'ha1 && holder.shifted[0] == 8'ha2
          && holder.shifted[1] == 8'ha3,
          "negative-bound indexed plus slice");
    check(holder.indexed_down[3] == 8'hb3
          && holder.indexed_down[4] == 8'hb4,
          "ascending declaration indexed minus slice");
    check(holder.single[0] == 8'h5a && holder.single[1] == 8'h61
          && holder.single[2] == 8'h62,
          "one-element slice and untouched neighbor");
    check(holder.overlap[0] == 1 && holder.overlap[1] == 3
          && holder.overlap[2] == 2 && holder.overlap[3] == 4,
          "property slice RHS snapshot");
    check(holder.real_values[0] == 0.0
          && holder.real_values[1] == 1.25
          && holder.real_values[2] == 2.5
          && holder.real_values[3] == 3.0,
          "real property slice");
    check(holder.string_values[3] == "old"
          && holder.string_values[2] == "two"
          && holder.string_values[1] == "one"
          && holder.string_values[0] == "old",
          "string property slice");

    holders[0] = new;
    holders[1] = new;
    holders[0].seed();
    holders[1].seed();
    receiver_calls = 0;
    rhs_calls = 0;
    holders[receiver_index()].overlap[1:2]
      = '{rhs_value(2), rhs_value(1)};
    check(receiver_calls == 1, "side-effecting receiver evaluated once");
    check(rhs_calls == 2, "each RHS leaf evaluated once");
    check(holders[1].overlap[0] == 1
          && holders[1].overlap[1] == 3
          && holders[1].overlap[2] == 2
          && holders[1].overlap[3] == 4,
          "side-effecting receiver RHS snapshot");

    $display("PASSED");
  end
endmodule
