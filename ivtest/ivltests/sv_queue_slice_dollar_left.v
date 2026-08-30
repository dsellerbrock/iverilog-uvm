// IEEE 1800-2017/2023 7.10.1: `$' denotes the current last queue index
// wherever it appears in a queue select. For Q[$:hi], an upper bound at or
// above `$' selects the last item, while a smaller or unknown bound produces
// the empty queue. The source queue expression and hi are each evaluated once.
module sv_queue_slice_dollar_left;
  class queue_box;
    int values[$];
  endclass

  class static_queue_box;
    static int values[$];
  endclass

  class slice_item;
    int value;
    function new(int value);
      this.value = value;
    endfunction
  endclass

  int q[$];
  int r[$];
  int bounded[$:4];
  logic [7:0] logic_q[$], logic_out[$];
  real real_q[$], real_out[$];
  string string_q[$], string_out[$];
  slice_item object_q[$], object_out[$];
  int nested_q[$][$], nested_out[$][$];
  slice_item item0, item1;
  queue_box box;
  queue_box boxes[$];
  int queue_idx;
  int receiver_calls;
  int upper_calls;
  integer unknown_bound;

  function automatic int receiver_index();
    receiver_calls++;
    return 0;
  endfunction

  function automatic int next_hi(input int value);
    upper_calls++;
    return value;
  endfunction

  initial begin
    q = {10, 20, 30, 40, 50};

    // The exact upper endpoint selects one item. An endpoint above the current
    // range clamps to `$'; an endpoint below `$' makes the range reversed.
    r = q[$:4];
    if (r.size() != 1 || r[0] != 50)
      $fatal(1, "exact left-$ slice failed: r=%p", r);
    r = q[$:99];
    if (r.size() != 1 || r[0] != 50)
      $fatal(1, "left-$ upper clamp failed: r=%p", r);
    r = q[$:3];
    if (r.size() != 0)
      $fatal(1, "reversed left-$ slice was not empty: r=%p", r);
    r = q[$:-1];
    if (r.size() != 0)
      $fatal(1, "negative upper left-$ slice was not empty: r=%p", r);

    // Reduced OpenTitan spi_device scoreboard cases. Its queue is nonempty,
    // capped at two elements, and queue_idx is a successful foreach index.
    q = {101};
    queue_idx = 0;
    q = q[$:queue_idx+1];
    if (q.size() != 1 || q[0] != 101)
      $fatal(1, "OpenTitan N=1/i=0 case failed: q=%p", q);
    q = {101, 102};
    queue_idx = 0;
    q = q[$:queue_idx+1];
    if (q.size() != 1 || q[0] != 102)
      $fatal(1, "OpenTitan N=2/i=0 case failed: q=%p", q);
    q = {101, 102};
    queue_idx = 1;
    q = q[$:queue_idx+1];
    if (q.size() != 1 || q[0] != 102)
      $fatal(1, "OpenTitan N=2/i=1 case failed: q=%p", q);

    // Either X or Z in the explicit endpoint makes the slice empty.
    q = {10, 20, 30, 40, 50};
    unknown_bound = 'x;
    r = q[$:unknown_bound];
    if (r.size() != 0)
      $fatal(1, "X upper bound did not produce an empty queue: r=%p", r);
    unknown_bound = 'z;
    r = q[$:unknown_bound];
    if (r.size() != 0)
      $fatal(1, "Z upper bound did not produce an empty queue: r=%p", r);

    // A range of a bounded queue is still an unbounded queue value. Type
    // queries must not evaluate their bounds.
    bounded = {1, 2, 3, 4, 5};
    upper_calls = 0;
    if ($typename(bounded[$:next_hi(99)]) != "int$[$]" ||
        upper_calls != 0)
      $fatal(1, "bounded left-$ slice type/evaluation failed: type=%s calls=%0d",
             $typename(bounded[$:99]), upper_calls);
    r = bounded[$:next_hi(99)];
    if (upper_calls != 1 || r.size() != 1 || r[0] != 5)
      $fatal(1, "bounded left-$ slice failed: calls=%0d r=%p",
             upper_calls, r);

    // A selected class-property receiver and its bound each run exactly once.
    // The same syntax in $typename is entirely unevaluated.
    box = new;
    box.values = {10, 20, 30, 40, 50};
    boxes = {box};
    receiver_calls = 0;
    upper_calls = 0;
    if ($typename(boxes[receiver_index()].values[$:next_hi(99)]) !=
          "int$[$]" || receiver_calls != 0 || upper_calls != 0)
      $fatal(1, "selected left-$ slice type/evaluation failed: calls=%0d/%0d",
             receiver_calls, upper_calls);
    r = boxes[receiver_index()].values[$:next_hi(99)];
    if (receiver_calls != 1 || upper_calls != 1 ||
        r.size() != 1 || r[0] != 50)
      $fatal(1, "selected left-$ receiver/bound repeated: calls=%0d/%0d r=%p",
             receiver_calls, upper_calls, r);
    receiver_calls = 0;
    upper_calls = 0;
    if (boxes[receiver_index()].values[$:next_hi(99)].size() != 1 ||
        receiver_calls != 1 || upper_calls != 1)
      $fatal(1, "method on selected left-$ slice failed: calls=%0d/%0d",
             receiver_calls, upper_calls);

    // The parameterized/scoped identifier grammar reaches the same lowering.
    static_queue_box::values = {7, 8, 9};
    upper_calls = 0;
    r = static_queue_box::values[$:next_hi(99)];
    if (upper_calls != 1 || r.size() != 1 || r[0] != 9)
      $fatal(1, "static-property left-$ slice failed: calls=%0d r=%p",
             upper_calls, r);

    // Exercise every runtime storage family. Class elements retain handle
    // identity; nested value containers are copied independently.
    logic_q = {8'h10, 8'h20};
    logic_out = logic_q[$:99];
    if (logic_out.size() != 1 || logic_out[0] != 8'h20)
      $fatal(1, "logic left-$ slice failed: out=%p", logic_out);
    real_q = {1.25, 2.5};
    real_out = real_q[$:99];
    if (real_out.size() != 1 || real_out[0] != 2.5)
      $fatal(1, "real left-$ slice failed: out=%p", real_out);
    string_q = {"zero", "one"};
    string_out = string_q[$:99];
    if (string_out.size() != 1 || string_out[0] != "one")
      $fatal(1, "string left-$ slice failed: out=%p", string_out);
    item0 = new(10);
    item1 = new(20);
    object_q = {item0, item1};
    object_out = object_q[$:99];
    if (object_out.size() != 1 || object_out[0] != item1)
      $fatal(1, "class-handle left-$ slice failed");
    object_out[0].value = 99;
    if (object_q[1].value != 99)
      $fatal(1, "class-handle left-$ slice lost handle identity");

    nested_q.push_back({1, 2});
    nested_q.push_back({3, 4});
    nested_out = nested_q[$:99];
    if (nested_out.size() != 1 || nested_out[0].size() != 2 ||
        nested_out[0][0] != 3 || nested_out[0][1] != 4)
      $fatal(1, "nested-value left-$ slice failed: out=%p", nested_out);
    nested_out[0][0] = 30;
    if (nested_q[1][0] != 3)
      $fatal(1, "nested left-$ result aliased its source: %p / %p",
             nested_q, nested_out);
    nested_q[1][1] = 40;
    if (nested_out[0][1] != 4)
      $fatal(1, "nested left-$ source aliased its result: %p / %p",
             nested_q, nested_out);

    // There is no last element in an empty queue. The result is empty, but
    // the explicit endpoint expression is still evaluated once.
    q = {};
    upper_calls = 0;
    r = q[$:next_hi(99)];
    if (upper_calls != 1 || r.size() != 0)
      $fatal(1, "empty left-$ slice failed: calls=%0d r=%p", upper_calls, r);

    $display("PASSED");
  end
endmodule
