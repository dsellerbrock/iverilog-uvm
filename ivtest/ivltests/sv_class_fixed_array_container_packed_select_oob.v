class packed_container_select_holder;
  logic [15:0] queue_words[0:1][$];
  logic [15:0] assoc_words[0:1][string];
  logic [15:0] cancel_queue[0:1][0:1][$];
  logic [15:0] cancel_assoc[0:1][0:1][string];
  logic [15:0] mixed_queue[1:-1][4:5][$];
  logic [15:0] mixed_assoc[-2:-1][3:2][string];
  logic [15:0] plain_queue[$];
  logic [15:0] plain_assoc[string];
endclass

module sv_class_fixed_array_container_packed_select_oob;
  bit failed;
  logic signed [31:0] first_index_value;
  logic signed [31:0] second_index_value;
  int first_index_calls;
  int second_index_calls;

  function automatic logic signed [31:0] next_first_index();
    first_index_calls++;
    return first_index_value;
  endfunction

  function automatic logic signed [31:0] next_second_index();
    second_index_calls++;
    return second_index_value;
  endfunction

  task automatic arm_index_probe(
      input logic signed [31:0] first_value,
      input logic signed [31:0] second_value);
    first_index_value = first_value;
    second_index_value = second_value;
    first_index_calls = 0;
    second_index_calls = 0;
  endtask

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    automatic packed_container_select_holder holder = new;
    automatic logic [15:0] source[$] = '{16'h1111, 16'h2222};
    automatic logic signed [0:0] signed_negative_outer = 1'sb1;
    automatic logic signed [31:0] unknown_outer = 'x;
    automatic int out_of_range_outer = 9;
    automatic int invalid_size;
    automatic int invalid_num;
    automatic logic [15:0] invalid_value;

    holder.queue_words[0].push_back(16'h0000);
    holder.queue_words[0][0][3] = 1'b1;
    holder.queue_words[0][0][7:4] = 4'ha;
    holder.queue_words[0][0][8 +: 4] = 4'h5;
    holder.queue_words[0][0][15 -: 4] = 4'hc;
    check("fixed queue packed l-value selects",
          holder.queue_words[0][0] == 16'hc5a8);
    check("fixed queue packed r-value selects",
          holder.queue_words[0][0][3] == 1'b1 &&
          holder.queue_words[0][0][7:4] == 4'ha &&
          holder.queue_words[0][0][8 +: 4] == 4'h5 &&
          holder.queue_words[0][0][15 -: 4] == 4'hc);

    holder.assoc_words[1]["key"] = 16'h0000;
    holder.assoc_words[1]["key"][2] = 1'b1;
    holder.assoc_words[1]["key"][6:3] = 4'hb;
    holder.assoc_words[1]["key"][7 +: 4] = 4'h6;
    holder.assoc_words[1]["key"][15 -: 4] = 4'hd;
    check("fixed associative packed l-value selects",
          holder.assoc_words[1]["key"] == 16'hd35c);
    check("fixed associative packed r-value selects",
          holder.assoc_words[1]["key"][2] == 1'b1 &&
          holder.assoc_words[1]["key"][6:3] == 4'hb &&
          holder.assoc_words[1]["key"][7 +: 4] == 4'h6 &&
          holder.assoc_words[1]["key"][15 -: 4] == 4'hd);

    holder.plain_queue.push_back(16'h0000);
    holder.plain_queue[0][3] = 1'b1;
    holder.plain_queue[0][7:4] = 4'ha;
    holder.plain_queue[0][8 +: 4] = 4'h5;
    holder.plain_queue[0][15 -: 4] = 4'hc;
    check("plain queue packed element selects",
          holder.plain_queue[0] == 16'hc5a8 &&
          holder.plain_queue[0][7:4] == 4'ha &&
          holder.plain_queue[0][8 +: 4] == 4'h5 &&
          holder.plain_queue[0][15 -: 4] == 4'hc);

    holder.plain_assoc["key"] = 16'h0000;
    holder.plain_assoc["key"][2] = 1'b1;
    holder.plain_assoc["key"][6:3] = 4'hb;
    holder.plain_assoc["key"][7 +: 4] = 4'h6;
    holder.plain_assoc["key"][15 -: 4] = 4'hd;
    check("plain associative packed element selects",
          holder.plain_assoc["key"] == 16'hd35c &&
          holder.plain_assoc["key"][6:3] == 4'hb &&
          holder.plain_assoc["key"][7 +: 4] == 4'h6 &&
          holder.plain_assoc["key"][15 -: 4] == 4'hd);

    // Both indices are individually invalid, but a naive row-major flattening
    // maps [-1][2] to slot zero. Per-dimension guards must reject the access
    // before either queue/map property can alias [0][0].
    holder.cancel_queue[0][0].push_back(16'h0c01);
    holder.cancel_assoc[0][0]["live"] = 16'h0a01;

    arm_index_probe(-1, 2);
    invalid_size =
        holder.cancel_queue[next_first_index()][next_second_index()].size();
    check("cancelling invalid queue size read is empty and evaluated once",
          invalid_size == 0 &&
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe(-1, 2);
    invalid_value =
        holder.cancel_queue[next_first_index()][next_second_index()][0];
    check("cancelling invalid queue element read cannot alias",
          $isunknown(invalid_value) &&
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe(-1, 2);
    holder.cancel_queue[next_first_index()][next_second_index()] = source;
    check("cancelling invalid whole-queue write is rejected once",
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe(-1, 2);
    holder.cancel_queue[next_first_index()][next_second_index()].push_back(
        16'hdead);
    check("cancelling invalid queue mutation cannot alias",
          first_index_calls == 1 && second_index_calls == 1 &&
          holder.cancel_queue[0][0].size() == 1 &&
          holder.cancel_queue[0][0][0] == 16'h0c01);

    arm_index_probe(-1, 2);
    invalid_num =
        holder.cancel_assoc[next_first_index()][next_second_index()].num();
    check("cancelling invalid map size read is empty and evaluated once",
          invalid_num == 0 &&
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe(-1, 2);
    invalid_value = holder.cancel_assoc[next_first_index()]
                                       [next_second_index()]["live"];
    check("cancelling invalid map element read cannot alias",
          $isunknown(invalid_value) &&
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe(-1, 2);
    holder.cancel_assoc[next_first_index()][next_second_index()]["live"] =
        16'hdead;
    check("cancelling invalid map mutation cannot alias",
          first_index_calls == 1 && second_index_calls == 1 &&
          holder.cancel_assoc[0][0].num() == 1 &&
          holder.cancel_assoc[0][0]["live"] == 16'h0a01);

    // Exercise descending/ascending and nonzero fixed dimensions. [2][6]
    // flattens to the live [1][4] queue slot if the two invalid offsets are
    // allowed to cancel. [0][4] similarly flattens to mixed_assoc[-1][2].
    holder.mixed_queue[1][4].push_back(16'h1c04);
    holder.mixed_assoc[-1][2]["live"] = 16'h1a02;

    arm_index_probe(2, 6);
    invalid_size =
        holder.mixed_queue[next_first_index()][next_second_index()].size();
    check("mixed-range cancelling queue read is empty and evaluated once",
          invalid_size == 0 &&
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe(2, 6);
    holder.mixed_queue[next_first_index()][next_second_index()] = source;
    check("mixed-range cancelling whole-queue write is rejected once",
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe(2, 6);
    holder.mixed_queue[next_first_index()][next_second_index()].push_back(
        16'hdead);
    check("mixed-range cancelling queue mutation cannot alias",
          first_index_calls == 1 && second_index_calls == 1 &&
          holder.mixed_queue[1][4].size() == 1 &&
          holder.mixed_queue[1][4][0] == 16'h1c04);

    arm_index_probe('x, 4);
    invalid_size =
        holder.mixed_queue[next_first_index()][next_second_index()].size();
    check("unknown first queue dimension is empty and evaluated once",
          invalid_size == 0 &&
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe(1, 'x);
    holder.mixed_queue[next_first_index()][next_second_index()].push_back(
        16'hdead);
    check("unknown second queue dimension cannot mutate",
          first_index_calls == 1 && second_index_calls == 1 &&
          holder.mixed_queue[1][4].size() == 1 &&
          holder.mixed_queue[1][4][0] == 16'h1c04);

    arm_index_probe(0, 4);
    invalid_num =
        holder.mixed_assoc[next_first_index()][next_second_index()].num();
    check("mixed-range cancelling map read is empty and evaluated once",
          invalid_num == 0 &&
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe(0, 4);
    invalid_value = holder.mixed_assoc[next_first_index()]
                                      [next_second_index()]["live"];
    check("mixed-range cancelling map element read cannot alias",
          $isunknown(invalid_value) &&
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe(0, 4);
    holder.mixed_assoc[next_first_index()][next_second_index()]["live"] =
        16'hdead;
    check("mixed-range cancelling map mutation cannot alias",
          first_index_calls == 1 && second_index_calls == 1 &&
          holder.mixed_assoc[-1][2].num() == 1 &&
          holder.mixed_assoc[-1][2]["live"] == 16'h1a02);

    arm_index_probe(-2, 'x);
    invalid_num =
        holder.mixed_assoc[next_first_index()][next_second_index()].num();
    check("unknown second map dimension is empty and evaluated once",
          invalid_num == 0 &&
          first_index_calls == 1 && second_index_calls == 1);
    arm_index_probe('x, 3);
    holder.mixed_assoc[next_first_index()][next_second_index()]["live"] =
        16'hdead;
    check("unknown first map dimension cannot mutate",
          first_index_calls == 1 && second_index_calls == 1 &&
          holder.mixed_assoc[-1][2].num() == 1 &&
          holder.mixed_assoc[-1][2]["live"] == 16'h1a02);

    check("literal invalid fixed-prefix reads return empty containers",
          holder.queue_words[9].size() == 0 &&
          holder.queue_words[32'hxxxx_xxxx].size() == 0 &&
          holder.assoc_words[9].num() == 0 &&
          holder.assoc_words[32'hxxxx_xxxx].num() == 0);
    check("literal invalid fixed-prefix element reads return defaults",
          $isunknown(holder.queue_words[9][0]) &&
          $isunknown(holder.queue_words[32'hxxxx_xxxx][0]) &&
          $isunknown(holder.assoc_words[9]["missing"]) &&
          $isunknown(holder.assoc_words[32'hxxxx_xxxx]["missing"]));

    holder.queue_words[9] = source;
    holder.queue_words[32'hxxxx_xxxx] = source;
    holder.queue_words[9].push_back(16'hffff);
    holder.queue_words[32'hxxxx_xxxx].push_back(16'heeee);
    holder.queue_words[9][0] = 16'hdddd;
    holder.queue_words[32'hxxxx_xxxx][0][3:0] = 4'hf;
    holder.assoc_words[9]["bad"] = 16'hffff;
    holder.assoc_words[32'hxxxx_xxxx]["bad"][7:4] = 4'hf;
    holder.assoc_words[9].delete("key");
    holder.assoc_words[32'hxxxx_xxxx].delete("key");
    holder.queue_words[out_of_range_outer] = source;
    holder.queue_words[unknown_outer].push_back(16'hbbbb);
    holder.queue_words[signed_negative_outer].push_back(16'haaaa);

    check("literal and runtime invalid fixed-prefix writes are no-ops",
          holder.queue_words[0].size() == 1 &&
          holder.queue_words[0][0] == 16'hc5a8 &&
          holder.queue_words[1].size() == 0 &&
          holder.assoc_words[0].num() == 0 &&
          holder.assoc_words[1].num() == 1 &&
          holder.assoc_words[1]["key"] == 16'hd35c &&
          holder.queue_words[9].size() == 0 &&
          holder.queue_words[32'hxxxx_xxxx].size() == 0 &&
          holder.assoc_words[9].num() == 0 &&
          holder.assoc_words[32'hxxxx_xxxx].num() == 0);

    if (failed)
      $fatal(1, "packed container select/OOB checks failed");
    $display("PASSED");
  end
endmodule
