// IEEE 1800-2017/2023 13.3.2 and 13.5: native task output arguments are
// copy-out only. Automatic formal storage starts at its declared default on
// every invocation, while static formal storage persists between invocations.
// Queue/dynamic-array values are copied independently; class handles stored in
// those containers remain handles.
class task_output_item;
  int value;
endclass

module sv_task_output_container_lifetime;
  int errors;
  int seen_q;
  int seen_d;
  int automatic_q_first[$];
  int automatic_q_second[$];
  int automatic_d_first[];
  int automatic_d_second[];
  int static_q_first[$];
  int static_q_second[$];
  int static_d_first[];
  int static_d_second[];
  int inout_q[$];
  task_output_item handle_q_first[$];
  task_output_item handle_q_second[$];
  task_output_item shared_handle;
  task_output_item replacement_handle;

  task check(input bit condition, input string what);
    if (!condition) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  task automatic replace_automatic(output int q[$], output int d[],
                                   output int initial_q_size,
                                   output int initial_d_size);
    initial_q_size = q.size();
    initial_d_size = d.size();
    q.push_back(11);
    d = new[1];
    d[0] = 13;
  endtask

  task replace_static(output int q[$], output int d[],
                      output int initial_q_size,
                      output int initial_d_size,
                      input bit replace_value);
    initial_q_size = q.size();
    initial_d_size = d.size();
    if (replace_value) begin
      q.delete();
      q.push_back(17);
      d = new[1];
      d[0] = 19;
    end
  endtask

  task retain_handle(output task_output_item q[$],
                     input bit replace_value,
                     input task_output_item value);
    if (replace_value) begin
      q.delete();
      q.push_back(value);
    end
  endtask

  task automatic append_inout(inout int q[$], output int initial_size);
    initial_size = q.size();
    q.push_back(53);
  endtask

  initial begin
    automatic_q_first.push_back(1);
    automatic_d_first = new[1];
    automatic_d_first[0] = 2;
    replace_automatic(automatic_q_first, automatic_d_first, seen_q, seen_d);
    check(seen_q == 0 && seen_d == 0
          && automatic_q_first.size() == 1
          && automatic_q_first[0] == 11
          && automatic_d_first.size() == 1
          && automatic_d_first[0] == 13,
          "automatic outputs begin at queue/darray defaults");

    automatic_q_second.push_back(3);
    automatic_d_second = new[1];
    automatic_d_second[0] = 5;
    replace_automatic(automatic_q_second, automatic_d_second,
                      seen_q, seen_d);
    check(seen_q == 0 && seen_d == 0
          && automatic_q_second.size() == 1
          && automatic_q_second[0] == 11
          && automatic_d_second.size() == 1
          && automatic_d_second[0] == 13,
          "automatic output defaults are restored on every call");

    replace_static(static_q_first, static_d_first, seen_q, seen_d, 1'b1);
    check(seen_q == 0 && seen_d == 0
          && static_q_first.size() == 1 && static_q_first[0] == 17
          && static_d_first.size() == 1 && static_d_first[0] == 19,
          "static output formal has its initial default");
    static_q_first[0] = 23;
    static_d_first[0] = 29;
    static_q_second.push_back(31);
    static_d_second = new[1];
    static_d_second[0] = 37;
    replace_static(static_q_second, static_d_second, seen_q, seen_d, 1'b0);
    check(seen_q == 1 && seen_d == 1
          && static_q_first[0] == 23 && static_d_first[0] == 29
          && static_q_second.size() == 1 && static_q_second[0] == 17
          && static_d_second.size() == 1 && static_d_second[0] == 19,
          "static outputs retain independent formal storage");

    shared_handle = new;
    shared_handle.value = 41;
    retain_handle(handle_q_first, 1'b1, shared_handle);
    handle_q_first[0].value = 43;
    replacement_handle = new;
    replacement_handle.value = 47;
    handle_q_first[0] = replacement_handle;
    handle_q_second.push_back(replacement_handle);
    retain_handle(handle_q_second, 1'b0, replacement_handle);
    check(handle_q_first[0] == replacement_handle
          && handle_q_second.size() == 1
          && handle_q_second[0] == shared_handle
          && handle_q_second[0].value == 43,
          "container values copy independently while class handles alias");

    inout_q.push_back(51);
    append_inout(inout_q, seen_q);
    check(seen_q == 1 && inout_q.size() == 2
          && inout_q[0] == 51 && inout_q[1] == 53,
          "inout queue still copies the caller value in");

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
