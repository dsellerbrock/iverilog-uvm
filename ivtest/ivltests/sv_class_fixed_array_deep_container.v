// A fixed class-property slot may contain further dynamic containers. Keep
// every trailing queue/dynamic/associative hop distinct and value-copied.

typedef logic [15:0] deep_vec_q_t[$];
typedef deep_vec_q_t deep_vec_qq_t[$];
typedef real deep_real_aa_t[string];
typedef deep_real_aa_t deep_real_aa_q_t[$];
typedef string deep_string_da_t[];
typedef deep_string_da_t deep_string_da_q_t[$];

class deep_container_leaf;
  int value;

  function new(int value = 0);
    this.value = value;
  endfunction

  function void bump();
    value++;
  endfunction
endclass

typedef deep_container_leaf deep_object_da_t[];
typedef deep_object_da_t deep_object_da_q_t[$];
typedef deep_container_leaf deep_object_q_t[$];
typedef real deep_real_assoc3_t[string][string][string];
typedef real deep_real_assoc2_t[string][string];
typedef deep_real_assoc2_t deep_real_assoc2_q_t[$];

class fixed_deep_container_holder;
  // fixed -> queue -> packed vector (packed-offset side-effect oracle)
  logic [15:0] vec_queue[0:1][$];
  // fixed -> queue -> queue -> queue -> packed vector
  deep_vec_qq_t queue_queue_queue[0:1][$];
  // fixed -> associative -> queue -> associative -> real
  deep_real_aa_q_t assoc_queue_assoc[0:1][string];
  // fixed -> associative -> queue -> dynamic array -> string / class handle
  deep_string_da_q_t assoc_queue_string_da[0:1][string];
  deep_object_da_q_t assoc_queue_object_da[0:1][string];
  // fixed -> associative -> queue -> class method receiver
  deep_object_q_t assoc_queue_class[0:1][string];
  // Deep associative and mixed positional/associative l-value chains.
  deep_real_assoc3_t assoc_assoc_assoc[0:1];
  deep_real_assoc2_q_t queue_assoc_assoc[0:1];
endclass

module sv_class_fixed_array_deep_container;
  bit failed;
  int index_calls;
  int tail_index_calls;
  int part_calls;
  int rhs_calls;
  logic signed [31:0] index_value;

  function automatic logic signed [31:0] next_index();
    index_calls++;
    return index_value;
  endfunction

  function automatic int next_tail_index();
    tail_index_calls++;
    return 0;
  endfunction

  function automatic int next_part();
    part_calls++;
    return 4;
  endfunction

  function automatic logic [15:0] next_vec();
    rhs_calls++;
    return 16'hdead;
  endfunction

  function automatic logic [3:0] next_nibble();
    rhs_calls++;
    return 4'hf;
  endfunction

  function automatic real next_real();
    rhs_calls++;
    return 9.5;
  endfunction

  function automatic string next_string();
    rhs_calls++;
    return "bad";
  endfunction

  deep_container_leaf rhs_object;
  function automatic deep_container_leaf next_object();
    rhs_calls++;
    return rhs_object;
  endfunction

  task automatic arm_index(input logic signed [31:0] value);
    index_value = value;
    index_calls = 0;
    tail_index_calls = 0;
    part_calls = 0;
    rhs_calls = 0;
  endtask

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    automatic fixed_deep_container_holder holder = new;
    automatic deep_vec_q_t vec_q = '{16'h1111, 16'h2222};
    automatic deep_vec_qq_t vec_qq;
    automatic deep_vec_qq_t vec_qq_copy;
    automatic deep_real_aa_t real_aa;
    automatic deep_real_aa_t real_aa_copy;
    automatic deep_real_aa_q_t real_aa_q;
    automatic deep_string_da_t string_da = new[2];
    automatic deep_string_da_t string_da_copy;
    automatic deep_string_da_q_t string_da_q;
    automatic deep_object_da_t object_da = new[2];
    automatic deep_object_da_t object_da_copy;
    automatic deep_object_da_q_t object_da_q;
    automatic deep_object_q_t method_q;
    automatic deep_container_leaf object_a = new(41);
    automatic deep_container_leaf object_b = new(42);
    automatic deep_container_leaf object_replacement = new(99);
    automatic deep_container_leaf method_object = new(7);
    automatic deep_container_leaf got_object;
    automatic logic [15:0] got_vec;
    automatic real got_real;
    automatic string got_string;

    vec_qq.push_back(vec_q);
    holder.vec_queue[0].push_back(16'h1234);
    holder.queue_queue_queue[0].push_back(vec_qq);

    real_aa["pi"] = 3.25;
    real_aa_q.push_back(real_aa);
    holder.assoc_queue_assoc[0]["live"] = real_aa_q;

    string_da[0] = "left";
    string_da[1] = "right";
    string_da_q.push_back(string_da);
    holder.assoc_queue_string_da[0]["live"] = string_da_q;

    object_da[0] = object_a;
    object_da[1] = object_b;
    object_da_q.push_back(object_da);
    holder.assoc_queue_object_da[0]["live"] = object_da_q;
    method_q.push_back(method_object);
    holder.assoc_queue_class[0]["live"] = method_q;
    rhs_object = object_replacement;

    begin
      automatic deep_real_assoc2_t assoc2;
      automatic deep_real_assoc2_q_t assoc2_q;
      assoc2_q.push_back(assoc2);
      holder.queue_assoc_assoc[0] = assoc2_q;
    end

    check("typed vec read through three trailing containers",
          holder.queue_queue_queue[0][0][0][0] == 16'h1111);
    check("typed real read through three trailing containers",
          holder.assoc_queue_assoc[0]["live"][0]["pi"] == 3.25);
    check("typed string read through three trailing containers",
          holder.assoc_queue_string_da[0]["live"][0][0] == "left");
    check("typed object read through three trailing containers",
          holder.assoc_queue_object_da[0]["live"][0][0] == object_a);
    holder.assoc_queue_class[0]["live"][0].bump();
    check("class method through associative and queue hops",
          method_object.value == 8);

    holder.assoc_assoc_assoc[0]["outer"]["middle"]["leaf"] = 12.5;
    check("three associative keys preserve every hop",
          holder.assoc_assoc_assoc[0]["outer"]["middle"]["leaf"] == 12.5 &&
          holder.assoc_assoc_assoc[0]["outer"]["middle"].exists("leaf") &&
          !holder.assoc_assoc_assoc[0]["outer"].exists("other") &&
          !holder.assoc_assoc_assoc[0].exists("other"));
    holder.queue_assoc_assoc[0][0]["middle"]["leaf"] = 6.25;
    check("queue then associative keys preserve every hop",
          holder.queue_assoc_assoc[0][0]["middle"]["leaf"] == 6.25 &&
          holder.queue_assoc_assoc[0][0]["middle"].exists("leaf") &&
          !holder.queue_assoc_assoc[0][0].exists("other"));

    // Container insertion/assignment is by value. Class elements inside the
    // copied dynamic array remain handles, but the dynamic-array shape itself
    // is not shared.
    vec_q[0] = 16'h9001;
    vec_qq[0][0] = 16'h9002;
    real_aa["pi"] = 9.25;
    real_aa_q[0]["pi"] = 9.5;
    string_da[0] = "source-mutated";
    string_da_q[0][0] = "queue-mutated";
    object_da[0] = object_replacement;
    object_da_q[0][0] = object_replacement;
    check("source queue copied into fixed selected leaf",
          holder.queue_queue_queue[0][0][0][0] == 16'h1111);
    check("source associative array copied into fixed selected leaf",
          holder.assoc_queue_assoc[0]["live"][0]["pi"] == 3.25);
    check("source string darray copied into fixed selected leaf",
          holder.assoc_queue_string_da[0]["live"][0][0] == "left");
    check("source object darray copied into fixed selected leaf",
          holder.assoc_queue_object_da[0]["live"][0][0] == object_a);

    // Reading any nested value container also returns a value copy. This is
    // especially important for a darray stored as a queue/map element: a
    // temporary assignment must not retain the backing vvp_object_t alias.
    vec_qq_copy = holder.queue_queue_queue[0][0];
    real_aa_copy = holder.assoc_queue_assoc[0]["live"][0];
    string_da_copy = holder.assoc_queue_string_da[0]["live"][0];
    object_da_copy = holder.assoc_queue_object_da[0]["live"][0];
    vec_qq_copy[0][0] = 16'h8001;
    real_aa_copy["pi"] = 8.25;
    string_da_copy[0] = "copy-mutated";
    object_da_copy[0] = object_replacement;
    check("nested queue read has value semantics",
          holder.queue_queue_queue[0][0][0][0] == 16'h1111);
    check("nested associative read has value semantics",
          holder.assoc_queue_assoc[0]["live"][0]["pi"] == 3.25);
    check("nested string darray read has value semantics",
          holder.assoc_queue_string_da[0]["live"][0][0] == "left");
    check("nested object darray read has value semantics",
          holder.assoc_queue_object_da[0]["live"][0][0] == object_a);

    // Invalid positions in any trailing positional container return the leaf
    // type's default and writes/mutators cannot alias position zero.
    arm_index(-1);
    got_vec = holder.queue_queue_queue[0][next_index()][0][0];
    check("invalid first queue read",
          $isunknown(got_vec) && index_calls == 1);
    arm_index('x);
    holder.queue_queue_queue[0][0][next_index()].push_back(16'hdead);
    check("invalid second queue mutator",
          index_calls == 1 &&
          holder.queue_queue_queue[0][0][0].size() == 2 &&
          holder.queue_queue_queue[0][0][0][0] == 16'h1111);
    arm_index('z);
    holder.queue_queue_queue[0][0][0][next_index()] = 16'hdead;
    check("invalid third queue write",
          index_calls == 1 &&
          holder.queue_queue_queue[0][0][0][0] == 16'h1111);

    arm_index(-1);
    got_real = holder.assoc_queue_assoc[0]["live"][next_index()]["pi"];
    check("invalid assoc-queue-assoc read",
          got_real == 0.0 && index_calls == 1);
    arm_index(9);
    holder.assoc_queue_assoc[0]["live"][next_index()]["pi"] = 7.5;
    check("invalid assoc-queue-assoc write",
          index_calls == 1 &&
          holder.assoc_queue_assoc[0]["live"][0]["pi"] == 3.25);

    arm_index('x);
    got_string =
        holder.assoc_queue_string_da[0]["live"][0][next_index()];
    check("invalid nested string darray read",
          got_string == "" && index_calls == 1);
    arm_index('z);
    holder.assoc_queue_string_da[0]["live"][0][next_index()] = "bad";
    check("invalid nested string darray write",
          index_calls == 1 &&
          holder.assoc_queue_string_da[0]["live"][0][0] == "left");

    arm_index(-1);
    got_object =
        holder.assoc_queue_object_da[0]["live"][0][next_index()];
    check("invalid nested object darray read",
          got_object == null && index_calls == 1);
    arm_index(9);
    holder.assoc_queue_object_da[0]["live"][0][next_index()] =
        object_replacement;
    check("invalid nested object darray write",
          index_calls == 1 &&
          holder.assoc_queue_object_da[0]["live"][0][0] == object_a);

    // The fixed prefix remains checked even with three dynamic tail hops.
    arm_index(-1);
    got_string =
        holder.assoc_queue_string_da[next_index()]["live"][0][0];
    check("invalid fixed prefix on deep read",
          got_string == "" && index_calls == 1);
    arm_index(-1);
    holder.assoc_queue_object_da[next_index()]["live"][0][0] =
        object_replacement;
    check("invalid fixed prefix on deep object write",
          index_calls == 1 &&
          holder.assoc_queue_object_da[0]["live"][0][0] == object_a);

    // Invalid fixed slots still evaluate and discard every remaining l-value
    // index/offset and the complete RHS once; the null/default receiver path
    // must not suppress source side effects.
    arm_index(-1);
    holder.queue_queue_queue[next_index()][next_tail_index()][0][0] =
        next_vec();
    check("invalid fixed deep vec write evaluates RHS once",
          index_calls == 1 && tail_index_calls == 1 && rhs_calls == 1 &&
          holder.queue_queue_queue[0][0][0][0] == 16'h1111);
    arm_index(-1);
    holder.vec_queue[next_index()][0][next_part() +: 4] =
        next_nibble();
    check("invalid fixed deep packed write evaluates offset/RHS once",
          index_calls == 1 && part_calls == 1 && rhs_calls == 1 &&
          holder.vec_queue[0][0] == 16'h1234);
    arm_index(-1);
    holder.assoc_queue_assoc[next_index()]["live"][next_tail_index()]["pi"] =
        next_real();
    check("invalid fixed deep real write evaluates RHS once",
          index_calls == 1 && tail_index_calls == 1 && rhs_calls == 1 &&
          holder.assoc_queue_assoc[0]["live"][0]["pi"] == 3.25);
    arm_index(-1);
    holder.assoc_queue_string_da[next_index()]["live"][0][next_tail_index()] =
        next_string();
    check("invalid fixed deep string write evaluates RHS once",
          index_calls == 1 && tail_index_calls == 1 && rhs_calls == 1 &&
          holder.assoc_queue_string_da[0]["live"][0][0] == "left");
    arm_index(-1);
    holder.assoc_queue_object_da[next_index()]["live"][0][next_tail_index()] =
        next_object();
    check("invalid fixed deep object write evaluates RHS once",
          index_calls == 1 && tail_index_calls == 1 && rhs_calls == 1 &&
          holder.assoc_queue_object_da[0]["live"][0][0] == object_a);

    // A method on the selected dynamic array must operate on that stored
    // value, and must evaluate the queue position only once.
    arm_index(0);
    holder.assoc_queue_string_da[0]["live"][next_index()].delete();
    check("selected nested string darray delete",
          index_calls == 1 &&
          holder.assoc_queue_string_da[0]["live"][0].size() == 0);
    arm_index(0);
    holder.assoc_queue_object_da[0]["live"][next_index()].delete();
    check("selected nested object darray delete",
          index_calls == 1 &&
          holder.assoc_queue_object_da[0]["live"][0].size() == 0);

    // Restore the deleted values, exercise deep queue/AA mutators, and then
    // read every type again. This catches object/vec/string/real stack drift.
    holder.assoc_queue_string_da[0]["live"][0] = string_da;
    holder.assoc_queue_object_da[0]["live"][0] = object_da;
    holder.queue_queue_queue[0][0][0].push_back(16'h3333);
    holder.assoc_queue_assoc[0]["live"][0]["tau"] = 6.5;
    holder.assoc_queue_assoc[0]["live"][0].delete("pi");
    check("continued valid deep queue operation",
          holder.queue_queue_queue[0][0][0].size() == 3 &&
          holder.queue_queue_queue[0][0][0][2] == 16'h3333);
    check("continued valid deep associative operation",
          holder.assoc_queue_assoc[0]["live"][0].num() == 1 &&
          holder.assoc_queue_assoc[0]["live"][0]["tau"] == 6.5);
    check("continued valid deep string operation",
          holder.assoc_queue_string_da[0]["live"][0][0] ==
              "source-mutated");
    check("continued valid deep object operation",
          holder.assoc_queue_object_da[0]["live"][0][0] ==
              object_replacement);
    check("fixed deep slots remain independent",
          holder.queue_queue_queue[1].size() == 0 &&
          holder.assoc_queue_assoc[1].num() == 0 &&
          holder.assoc_queue_string_da[1].num() == 0 &&
          holder.assoc_queue_object_da[1].num() == 0);

    if (failed)
      $fatal(1, "fixed deep-container property checks failed");
    $display("PASSED");
  end
endmodule
