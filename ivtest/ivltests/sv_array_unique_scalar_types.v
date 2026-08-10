// IEEE 1800-2017 7.12.1: plain unique()/unique_index() use the
// receiver element value as the key. Exercise every scalar VVP container
// representation, including exact four-state values, and verify that the
// locator result is fresh and the receiver is not mutated.
class int_collection;
  int values[];
  int queued[$];
endclass

module main;
  real real_values[];
  real real_queue[$];
  real real_result[$];
  string string_values[];
  string string_queue[$];
  string string_result[$];
  logic [3:0] logic_values[];
  logic [3:0] logic_queue[$];
  logic [3:0] logic_result[$];
  int indexes[$];
  int int_result[$];
  int_collection holder;
  bit failed;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  task automatic check_int_values(input string label, input int got[$]);
    got.sort();
    check(label, got.size() == 3
          && got[0] == 7 && got[1] == 9 && got[2] == 11);
  endtask

  task automatic check_holder_queue_indexes(input string label,
                                               input int got[$]);
    bit got_4;
    bit got_6;
    int j;
    got_4 = 1'b0;
    got_6 = 1'b0;
    for (j = 0; j < got.size(); j = j + 1) begin
      check("class-property unique_index range",
            got[j] >= 0 && got[j] < holder.queued.size());
      if (got[j] >= 0 && got[j] < holder.queued.size()) begin
        if (holder.queued[got[j]] == 4)
          got_4 = 1'b1;
        else if (holder.queued[got[j]] == 6)
          got_6 = 1'b1;
        else
          check("class-property unique_index source value", 1'b0);
      end
    end
    check(label, got.size() == 2 && got_4 && got_6);
  endtask

  task automatic check_real_dynamic_indexes(input string label,
                                              input int got[$]);
    bit got_neg_2_25;
    bit got_zero;
    bit got_1_5;
    bit got_3_75;
    int j;
    got_neg_2_25 = 1'b0;
    got_zero = 1'b0;
    got_1_5 = 1'b0;
    got_3_75 = 1'b0;
    for (j = 0; j < got.size(); j = j + 1) begin
      check("real unique_index range",
            got[j] >= 0 && got[j] < real_values.size());
      if (got[j] >= 0 && got[j] < real_values.size()) begin
        if (real_values[got[j]] == -2.25)
          got_neg_2_25 = 1'b1;
        else if (real_values[got[j]] == 0.0)
          got_zero = 1'b1;
        else if (real_values[got[j]] == 1.5)
          got_1_5 = 1'b1;
        else if (real_values[got[j]] == 3.75)
          got_3_75 = 1'b1;
        else
          check("real unique_index source value", 1'b0);
      end
    end
    check(label, got.size() == 4
          && got_neg_2_25 && got_zero && got_1_5 && got_3_75);
  endtask

  task automatic check_string_dynamic_indexes(input string label,
                                                input int got[$]);
    bit got_empty;
    bit got_alpha;
    bit got_beta;
    bit got_gamma;
    int j;
    got_empty = 1'b0;
    got_alpha = 1'b0;
    got_beta = 1'b0;
    got_gamma = 1'b0;
    for (j = 0; j < got.size(); j = j + 1) begin
      check("string unique_index range",
            got[j] >= 0 && got[j] < string_values.size());
      if (got[j] >= 0 && got[j] < string_values.size()) begin
        if (string_values[got[j]] == "")
          got_empty = 1'b1;
        else if (string_values[got[j]] == "Alpha")
          got_alpha = 1'b1;
        else if (string_values[got[j]] == "beta")
          got_beta = 1'b1;
        else if (string_values[got[j]] == "Gamma")
          got_gamma = 1'b1;
        else
          check("string unique_index source value", 1'b0);
      end
    end
    check(label, got.size() == 4
          && got_empty && got_alpha && got_beta && got_gamma);
  endtask

  task automatic check_logic_values(input string label,
                                      input logic [3:0] got[$]);
    bit got_x001;
    bit got_z010;
    bit got_1010;
    bit got_x010;
    bit got_zzzz;
    int j;
    got_x001 = 1'b0;
    got_z010 = 1'b0;
    got_1010 = 1'b0;
    got_x010 = 1'b0;
    got_zzzz = 1'b0;
    for (j = 0; j < got.size(); j = j + 1) begin
      if (got[j] === 4'bx001)
        got_x001 = 1'b1;
      else if (got[j] === 4'bz010)
        got_z010 = 1'b1;
      else if (got[j] === 4'b1010)
        got_1010 = 1'b1;
      else if (got[j] === 4'bx010)
        got_x010 = 1'b1;
      else if (got[j] === 4'bzzzz)
        got_zzzz = 1'b1;
      else
        check("four-state unique value class", 1'b0);
    end
    check(label, got.size() == 5
          && got_x001 && got_z010 && got_1010 && got_x010 && got_zzzz);
  endtask

  task automatic check_logic_dynamic_indexes(input string label,
                                               input int got[$]);
    logic [3:0] represented[$];
    int j;
    for (j = 0; j < got.size(); j = j + 1) begin
      check("four-state unique_index range",
            got[j] >= 0 && got[j] < logic_values.size());
      if (got[j] >= 0 && got[j] < logic_values.size())
        represented.push_back(logic_values[got[j]]);
    end
    check_logic_values(label, represented);
  endtask

  task automatic check_logic_queue_values(input string label,
                                            input logic [3:0] got[$]);
    bit got_10xz;
    bit got_10zx;
    int j;
    got_10xz = 1'b0;
    got_10zx = 1'b0;
    for (j = 0; j < got.size(); j = j + 1) begin
      if (got[j] === 4'b10xz)
        got_10xz = 1'b1;
      else if (got[j] === 4'b10zx)
        got_10zx = 1'b1;
      else
        check("four-state queue unique value class", 1'b0);
    end
    check(label, got.size() == 2 && got_10xz && got_10zx);
  endtask

  initial begin
    failed = 1'b0;

    holder = new;
    holder.values = new[5];
    holder.values[0] = 7;
    holder.values[1] = 7;
    holder.values[2] = 9;
    holder.values[3] = 11;
    holder.values[4] = 9;
    int_result = holder.values.unique();
    check_int_values("dynamic-array class-property receiver", int_result);
    holder.queued.push_back(4);
    holder.queued.push_back(4);
    holder.queued.push_back(6);
    indexes = holder.queued.unique_index;
    check_holder_queue_indexes("parenless queue class-property receiver",
                               indexes);
    holder.values.unique();
    check("discarded class-property locator leaves receiver unchanged",
          holder.values.size() == 5 && holder.values[4] == 9);

    real_values = new[6];
    real_values[0] = 1.5;
    real_values[1] = -2.25;
    real_values[2] = 1.5;
    real_values[3] = 0.0;
    real_values[4] = -2.25;
    real_values[5] = 3.75;
    real_result = real_values.unique;
    indexes = real_values.unique_index;
    real_result.sort();
    check("real dynamic unique values",
          real_result.size() == 4
          && real_result[0] == -2.25 && real_result[1] == 0.0
          && real_result[2] == 1.5 && real_result[3] == 3.75);
    check_real_dynamic_indexes("real dynamic unique indexes", indexes);

    real_queue.push_back(2.0);
    real_queue.push_back(2.0);
    real_queue.push_back(-1.0);
    real_result = real_queue.unique();
    real_result.sort();
    check("real queue unique",
          real_result.size() == 2
          && real_result[0] == -1.0 && real_result[1] == 2.0);
    real_result.push_back(9.0);
    check("real result is fresh",
          real_queue.size() == 3 && real_result.size() == 3);

    string_values = new[6];
    string_values[0] = "Alpha";
    string_values[1] = "beta";
    string_values[2] = "Alpha";
    string_values[3] = "";
    string_values[4] = "beta";
    string_values[5] = "Gamma";
    string_result = string_values.unique;
    indexes = string_values.unique_index;
    string_result.sort();
    check("string dynamic unique values",
          string_result.size() == 4
          && string_result[0] == "" && string_result[1] == "Alpha"
          && string_result[2] == "Gamma" && string_result[3] == "beta");
    check_string_dynamic_indexes("string dynamic unique indexes", indexes);

    string_queue.push_back("same");
    string_queue.push_back("same");
    string_queue.push_back("different");
    string_result = string_queue.unique();
    string_result.sort();
    check("string queue unique",
          string_result.size() == 2
          && string_result[0] == "different"
          && string_result[1] == "same");
    string_result.push_back("fresh");
    check("string result is fresh",
          string_queue.size() == 3 && string_result.size() == 3);

    logic_values = new[8];
    logic_values[0] = 4'bx001;
    logic_values[1] = 4'bz010;
    logic_values[2] = 4'bx001;
    logic_values[3] = 4'b1010;
    logic_values[4] = 4'bz010;
    logic_values[5] = 4'bx010;
    logic_values[6] = 4'b1010;
    logic_values[7] = 4'bzzzz;
    logic_result = logic_values.unique;
    indexes = logic_values.unique_index;
    check_logic_values("four-state dynamic unique values", logic_result);
    check_logic_dynamic_indexes("four-state dynamic unique indexes", indexes);

    logic_queue.push_back(4'b10xz);
    logic_queue.push_back(4'b10xz);
    logic_queue.push_back(4'b10zx);
    logic_result = logic_queue.unique();
    check_logic_queue_values("four-state queue preserves X/Z distinctions",
                             logic_result);
    logic_result.push_back(4'b0001);
    check("four-state result is fresh",
          logic_queue.size() == 3 && logic_result.size() == 3);

    real_queue.unique();
    string_queue.unique_index();
    logic_values.unique();
    check("discarded scalar locator results do not mutate receivers",
          real_queue.size() == 3
          && string_queue.size() == 3
          && logic_values.size() == 8);

    if (failed)
      $fatal(1, "scalar unique checks failed");
    $display("PASSED");
  end
endmodule
