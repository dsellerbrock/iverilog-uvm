// Fixed-array materialization encodes integral widths through 255 bits.
// Keep that boundary working, and ensure the fixed-only implementation limit
// does not leak into ordinary object-backed dynamic arrays or queues.
typedef logic [254:0] unique_word255_t;
typedef logic [299:0] unique_word300_t;
typedef unique_word255_t unique_fixed255_t[-1:2];
typedef string unique_fixed_string_t[3:6];

module main;
  localparam unique_word255_t F_A = {1'b1, 253'b0, 1'b1};
  localparam unique_word255_t F_B = {1'b0, 1'b1, 252'b0, 1'b1};
  localparam unique_word255_t F_C = {2'b0, 1'b1, 251'b0, 1'b1};
  localparam unique_word300_t W_A = {1'b1, 298'b0, 1'b1};
  localparam unique_word300_t W_B = {1'b0, 1'b1, 297'b0, 1'b1};
  localparam unique_word300_t W_C = {2'b0, 1'b1, 296'b0, 1'b1};

  unique_word255_t fixed_values[-1:2];
  unique_word255_t fixed_result[$];
  unique_word300_t dynamic_values[];
  unique_word300_t queue_values[$];
  unique_word300_t wide_result[$];
  string string_result[$];
  int indexes[$];
  int fixed_function_calls;
  bit failed;

  function automatic unique_fixed255_t make_fixed_values();
    fixed_function_calls = fixed_function_calls + 1;
    make_fixed_values[-1] = F_A;
    make_fixed_values[0] = F_B;
    make_fixed_values[1] = F_A;
    make_fixed_values[2] = F_C;
  endfunction

  function automatic unique_fixed_string_t make_fixed_strings();
    fixed_function_calls = fixed_function_calls + 1;
    make_fixed_strings = '{"red", "blue", "red", "green"};
  endfunction

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  task automatic check_fixed_values(input string label,
                                    input unique_word255_t got[$]);
    bit seen_a;
    bit seen_b;
    bit seen_c;
    int i;
    seen_a = 1'b0;
    seen_b = 1'b0;
    seen_c = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      if (got[i] === F_A) begin
        check("one fixed-width A", !seen_a); seen_a = 1'b1;
      end else if (got[i] === F_B) begin
        check("one fixed-width B", !seen_b); seen_b = 1'b1;
      end else if (got[i] === F_C) begin
        check("one fixed-width C", !seen_c); seen_c = 1'b1;
      end else begin
        check("unexpected fixed-width value", 1'b0);
      end
    end
    check(label, seen_a && seen_b && seen_c);
  endtask

  task automatic check_fixed_indexes(input string label,
                                     input int got[$]);
    unique_word255_t represented[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("width-255 fixed declared index",
            got[i] >= -1 && got[i] <= 2);
      if (got[i] >= -1 && got[i] <= 2)
        represented.push_back(fixed_values[got[i]]);
    end
    check_fixed_values(label, represented);
  endtask

  task automatic check_string_values(input string label,
                                     input string got[$]);
    bit seen_red;
    bit seen_blue;
    bit seen_green;
    int i;
    seen_red = 1'b0;
    seen_blue = 1'b0;
    seen_green = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      if (got[i] == "red") begin
        check("one fixed-function red", !seen_red); seen_red = 1'b1;
      end else if (got[i] == "blue") begin
        check("one fixed-function blue", !seen_blue); seen_blue = 1'b1;
      end else if (got[i] == "green") begin
        check("one fixed-function green", !seen_green); seen_green = 1'b1;
      end else begin
        check("unexpected fixed-function string", 1'b0);
      end
    end
    check(label, seen_red && seen_blue && seen_green);
  endtask

  task automatic check_string_indexes(input string label,
                                      input int got[$]);
    string represented[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("fixed-function string declared index",
            got[i] >= 3 && got[i] <= 6);
      case (got[i])
        3, 5: represented.push_back("red");
        4: represented.push_back("blue");
        6: represented.push_back("green");
        default: ;
      endcase
    end
    check_string_values(label, represented);
  endtask

  task automatic check_wide_values(input string label,
                                   input unique_word300_t got[$]);
    bit seen_a;
    bit seen_b;
    bit seen_c;
    int i;
    seen_a = 1'b0;
    seen_b = 1'b0;
    seen_c = 1'b0;
    check(label, got.size() == 3);
    for (i = 0; i < got.size(); i = i + 1) begin
      if (got[i] === W_A) begin
        check("one object-backed wide A", !seen_a); seen_a = 1'b1;
      end else if (got[i] === W_B) begin
        check("one object-backed wide B", !seen_b); seen_b = 1'b1;
      end else if (got[i] === W_C) begin
        check("one object-backed wide C", !seen_c); seen_c = 1'b1;
      end else begin
        check("unexpected object-backed wide value", 1'b0);
      end
    end
    check(label, seen_a && seen_b && seen_c);
  endtask

  task automatic check_dynamic_indexes(input string label,
                                       input int got[$]);
    unique_word300_t represented[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("width-300 dynamic index", got[i] >= 0 && got[i] < 4);
      if (got[i] >= 0 && got[i] < 4)
        represented.push_back(dynamic_values[got[i]]);
    end
    check_wide_values(label, represented);
  endtask

  task automatic check_queue_indexes(input string label,
                                     input int got[$]);
    unique_word300_t represented[$];
    int i;
    for (i = 0; i < got.size(); i = i + 1) begin
      check("width-300 queue index", got[i] >= 0 && got[i] < 4);
      if (got[i] >= 0 && got[i] < 4)
        represented.push_back(queue_values[got[i]]);
    end
    check_wide_values(label, represented);
  endtask

  initial begin
    failed = 1'b0;
    fixed_values[-1] = F_A;
    fixed_values[0] = F_B;
    fixed_values[1] = F_A;
    fixed_values[2] = F_C;

    fixed_result = fixed_values.unique;
    check_fixed_values("width-255 fixed unique", fixed_result);
    indexes = fixed_values.unique_index();
    check_fixed_indexes("width-255 fixed unique_index", indexes);

    fixed_function_calls = 0;
    fixed_result = make_fixed_values().unique();
    check("explicit fixed function unique receiver evaluated once",
          fixed_function_calls == 1);
    check_fixed_values("explicit fixed function unique", fixed_result);

    fixed_function_calls = 0;
    fixed_result = make_fixed_values().unique;
    check("parenless fixed function unique receiver evaluated once",
          fixed_function_calls == 1);
    check_fixed_values("parenless fixed function unique", fixed_result);

    fixed_function_calls = 0;
    indexes = make_fixed_values().unique_index();
    check("explicit fixed function unique_index receiver evaluated once",
          fixed_function_calls == 1);
    check_fixed_indexes("explicit fixed function unique_index", indexes);

    fixed_function_calls = 0;
    indexes = make_fixed_values().unique_index;
    check("parenless fixed function unique_index receiver evaluated once",
          fixed_function_calls == 1);
    check_fixed_indexes("parenless fixed function unique_index", indexes);

    fixed_function_calls = 0;
    string_result = make_fixed_strings().unique();
    check("explicit fixed string function unique evaluated once",
          fixed_function_calls == 1);
    check_string_values("explicit fixed string function unique", string_result);

    fixed_function_calls = 0;
    string_result = make_fixed_strings().unique;
    check("parenless fixed string function unique evaluated once",
          fixed_function_calls == 1);
    check_string_values("parenless fixed string function unique", string_result);

    fixed_function_calls = 0;
    indexes = make_fixed_strings().unique_index();
    check("explicit fixed string function unique_index evaluated once",
          fixed_function_calls == 1);
    check_string_indexes("explicit fixed string function unique_index", indexes);

    fixed_function_calls = 0;
    indexes = make_fixed_strings().unique_index;
    check("parenless fixed string function unique_index evaluated once",
          fixed_function_calls == 1);
    check_string_indexes("parenless fixed string function unique_index", indexes);

    dynamic_values = new[4];
    dynamic_values[0] = W_A;
    dynamic_values[1] = W_B;
    dynamic_values[2] = W_A;
    dynamic_values[3] = W_C;
    wide_result = dynamic_values.unique();
    check_wide_values("width-300 dynamic unique", wide_result);
    indexes = dynamic_values.unique_index;
    check_dynamic_indexes("width-300 dynamic unique_index", indexes);

    queue_values = '{W_A, W_B, W_A, W_C};
    wide_result = queue_values.unique;
    check_wide_values("width-300 queue unique", wide_result);
    indexes = queue_values.unique_index();
    check_queue_indexes("width-300 queue unique_index", indexes);

    if (failed)
      $fatal(1, "unique width-boundary checks failed");
    $display("PASSED");
  end
endmodule
