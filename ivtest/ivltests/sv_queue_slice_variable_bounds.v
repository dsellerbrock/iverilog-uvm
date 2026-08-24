// IEEE 1800-2017 7.10.1: queue slice bounds are arbitrary integral
// expressions. The resulting queue contains the inclusive ascending range;
// reversed, unknown, or wholly out-of-range bounds produce an empty queue.
module top;
  class queue_box;
    int values[$];
  endclass

  class static_queue_box;
    static int values[$];
  endclass

  class queue_slice_item;
    int value;
    function new(int value);
      this.value = value;
    endfunction
  endclass

  int q[$];
  int r[$];
  int bounded[$:3];
  bit [7:0] bit_q[$], bit_out[$];
  real real_q[$], real_out[$];
  string string_q[$], string_out[$];
  queue_slice_item object_q[$], object_out[$];
  queue_slice_item item0, item1, item2;
  int typed_width;
  int lo_calls;
  int hi_calls;
  int receiver_calls;
  int base_calls;
  int width_calls;
  integer unknown_bound;
  bit one_bit;
  bit signed minus_one_bit;
  int unsigned huge_unsigned;
  bit [127:0] huge_wide;
  bit signed [127:0] negative_wide;
  bit signed [64:0] below_int64;
  queue_box box;
  queue_box boxes[$];
  int queue_of_queues[$][$];
  int sliced_queue_of_queues[$][$];
  bit stream_bits[$];
  byte unsigned stream_data[];
  int stream_lo;
  int stream_hi;
  string slice_text;

  function automatic int next_lo();
    lo_calls++;
    return 1;
  endfunction

  function automatic int next_hi();
    hi_calls++;
    return 3;
  endfunction

  function automatic int receiver_index();
    receiver_calls++;
    return 0;
  endfunction

  function automatic int next_base(input int value);
    base_calls++;
    return value;
  endfunction

  function automatic int next_width(input int value);
    width_calls++;
    return value;
  endfunction

  initial begin
    q = {10, 20, 30, 40, 50};

    // Queue slice bounds may be arbitrary integral expressions in every range
    // spelling. Both indexed spellings normalize to ascending queue order,
    // and the receiver, base, and width are each evaluated exactly once.
    base_calls = 0;
    width_calls = 0;
    lo_calls = 0;
    hi_calls = 0;
    if ($typename(q[next_base(1) +: next_width(3)]) != "int$[$]" ||
        $typename(q[next_lo():next_hi()]) != "int$[$]" ||
        base_calls != 0 || width_calls != 0 ||
        lo_calls != 0 || hi_calls != 0)
      $fatal(1, "slice type resolution/evaluation failed: %s / %s calls=%0d/%0d/%0d/%0d",
             $typename(q[1 +: 3]), $typename(q[1:3]),
             base_calls, width_calls, lo_calls, hi_calls);
    base_calls = 0;
    width_calls = 0;
    r = q[next_base(1) +: next_width(3)];
    if (base_calls != 1 || width_calls != 1 || r.size() != 3 ||
        r[0] != 20 || r[1] != 30 || r[2] != 40)
      $fatal(1, "queue +: slice failed: calls=%0d/%0d r=%p",
             base_calls, width_calls, r);
    base_calls = 0;
    width_calls = 0;
    r = q[next_base(3) -: next_width(3)];
    if (base_calls != 1 || width_calls != 1 || r.size() != 3 ||
        r[0] != 20 || r[1] != 30 || r[2] != 40)
      $fatal(1, "queue -: slice failed: calls=%0d/%0d r=%p",
             base_calls, width_calls, r);
    base_calls = 0;
    width_calls = 0;
    if (q[next_base(1) +: next_width(3)].size() != 3 ||
        base_calls != 1 || width_calls != 1)
      $fatal(1, "method on indexed queue slice failed: calls=%0d/%0d",
             base_calls, width_calls);

    // A range of a bounded queue is still an unbounded queue value. Type
    // queries are unevaluated, while run-time use evaluates each operand once.
    bounded = {10, 20, 30, 40};
    base_calls = 0;
    width_calls = 0;
    if ($typename(bounded[next_base(1) +: next_width(2)]) != "int$[$]" ||
        $typename(bounded[next_base(0):next_width(2)]) != "int$[$]" ||
        base_calls != 0 || width_calls != 0)
      $fatal(1, "bounded queue slice type/calls failed: %s %0d/%0d",
             $typename(bounded[1 +: 2]), base_calls, width_calls);
    r = bounded[next_base(1) +: next_width(2)];
    if (r.size() != 2 || r[0] != 20 || r[1] != 30 ||
        base_calls != 1 || width_calls != 1)
      $fatal(1, "bounded queue indexed slice failed: %p %0d/%0d",
             r, base_calls, width_calls);
    if (bounded[next_base(0):next_width(2)].size() != 3 ||
        base_calls != 2 || width_calls != 2)
      $fatal(1, "bounded queue colon method failed: %0d/%0d",
             base_calls, width_calls);

    // The indexed-slice bytecode carries the element kind. Exercise every
    // runtime storage family and preserve class-handle copy semantics.
    typed_width = 2;
    bit_q = {8'h10, 8'h20, 8'h30};
    bit_out = bit_q[1 +: typed_width];
    if (bit_out.size() != 2 || bit_out[0] != 8'h20 || bit_out[1] != 8'h30)
      $fatal(1, "bit queue indexed slice failed: %p", bit_out);
    real_q = {1.25, 2.5, 3.75};
    real_out = real_q[2 -: typed_width];
    if (real_out.size() != 2 || real_out[0] != 2.5 || real_out[1] != 3.75)
      $fatal(1, "real queue indexed slice failed: %p", real_out);
    string_q = {"zero", "one", "two"};
    string_out = string_q[1 +: typed_width];
    if (string_out.size() != 2 || string_out[0] != "one" ||
        string_out[1] != "two")
      $fatal(1, "string queue indexed slice failed: %p", string_out);
    item0 = new(10);
    item1 = new(20);
    item2 = new(30);
    object_q = {item0, item1, item2};
    object_out = object_q[2 -: typed_width];
    if (object_out.size() != 2 || object_out[0] != object_q[1] ||
        object_out[1] != object_q[2])
      $fatal(1, "class queue indexed slice failed");
    object_out[0].value = 99;
    if (object_q[1].value != 99)
      $fatal(1, "class queue slice did not preserve handle semantics");

    // Queue indexed slices use the same 7.10.1 endpoint clamping rules.
    r = q[3 +: 3];
    if (r.size() != 2 || r[0] != 40 || r[1] != 50)
      $fatal(1, "out-of-range queue indexed slice did not clamp: %p", r);

    r = q[next_lo():next_hi()];
    if (lo_calls != 1 || hi_calls != 1 || r.size() != 3 ||
        r[0] != 20 || r[1] != 30 || r[2] != 40)
      $fatal(1, "variable bounds or single evaluation failed: r=%p", r);

    lo_calls = 0;
    hi_calls = 0;
    if (q[next_lo():next_hi()].size() != 3 ||
        lo_calls != 1 || hi_calls != 1)
      $fatal(1, "method on variable slice failed: calls=%0d/%0d",
             lo_calls, hi_calls);
    if (q[1:3].pop_front() != 20 || q.size() != 5 || q[1] != 20)
      $fatal(1, "mutating method on slice changed its source: q=%p", q);

    // A slice on an inner queue must retain the already evaluated outer
    // element select. The old multi-index walk consumed the range as a
    // scalar index and silently sliced the outer queue instead.
    queue_of_queues.push_back({10, 20, 30, 40, 50});
    lo_calls = 0;
    hi_calls = 0;
    receiver_calls = 0;
    r = queue_of_queues[receiver_index()][next_lo():next_hi()];
    if (receiver_calls != 1 || lo_calls != 1 || hi_calls != 1 ||
        r.size() != 3 || r[0] != 20 || r[1] != 30 || r[2] != 40)
      $fatal(1, "nested queue slice failed: calls=%0d/%0d/%0d r=%p",
             receiver_calls, lo_calls, hi_calls, r);
    lo_calls = 0;
    hi_calls = 0;
    receiver_calls = 0;
    slice_text = $sformatf("%p", queue_of_queues[receiver_index()]
                                     [next_lo():next_hi()]);
    if (receiver_calls != 1 || lo_calls != 1 || hi_calls != 1 ||
        slice_text != "'{20, 30, 40}")
      $fatal(1, "untyped nested queue slice failed: calls=%0d/%0d/%0d text=%s",
             receiver_calls, lo_calls, hi_calls, slice_text);
    base_calls = 0;
    receiver_calls = 0;
    r = queue_of_queues[receiver_index()][next_base(3) -: 3];
    if (receiver_calls != 1 || base_calls != 1 || r.size() != 3 ||
        r[0] != 20 || r[1] != 30 || r[2] != 40)
      $fatal(1, "nested indexed queue slice failed: calls=%0d/%0d r=%p",
             receiver_calls, base_calls, r);
    base_calls = 0;
    width_calls = 0;
    receiver_calls = 0;
    if (queue_of_queues[receiver_index()]
                        [next_base(1) +: next_width(3)].size() != 3 ||
        receiver_calls != 1 || base_calls != 1 || width_calls != 1)
      $fatal(1, "method on nested indexed queue slice failed: calls=%0d/%0d/%0d",
             receiver_calls, base_calls, width_calls);

    // Slice assignment copies nested unpacked value elements. Mutating either
    // side afterwards must not alias the inner queues.
    sliced_queue_of_queues = queue_of_queues[0:0];
    sliced_queue_of_queues[0][0] = 99;
    if (queue_of_queues[0][0] != 10)
      $fatal(1, "queue slice aliased source nested value: source=%p result=%p",
             queue_of_queues, sliced_queue_of_queues);
    queue_of_queues[0][1] = 88;
    if (sliced_queue_of_queues[0][1] != 20)
      $fatal(1, "queue slice aliased result nested value: source=%p result=%p",
             queue_of_queues, sliced_queue_of_queues);
    queue_of_queues[0][0] = 10;
    queue_of_queues[0][1] = 20;

    // Scoped static properties use signal-backed storage but have the same
    // queue slice semantics and arbitrary-bound rule.
    static_queue_box::values = q;
    lo_calls = 0;
    hi_calls = 0;
    r = static_queue_box::values[next_lo():next_hi()];
    if (lo_calls != 1 || hi_calls != 1 || r.size() != 3 ||
        r[0] != 20 || r[1] != 30 || r[2] != 40)
      $fatal(1, "static queue-property slice failed: calls=%0d/%0d r=%p",
             lo_calls, hi_calls, r);
    lo_calls = 0;
    hi_calls = 0;
    slice_text = $sformatf("%p",
                           static_queue_box::values[next_lo():next_hi()]);
    if (lo_calls != 1 || hi_calls != 1 ||
        slice_text != "'{20, 30, 40}")
      $fatal(1, "untyped static queue slice failed: calls=%0d/%0d text=%s",
             lo_calls, hi_calls, slice_text);
    base_calls = 0;
    width_calls = 0;
    r = static_queue_box::values[next_base(3) -: next_width(3)];
    if (base_calls != 1 || width_calls != 1 || r.size() != 3 || r[0] != 20 ||
        r[1] != 30 || r[2] != 40)
      $fatal(1, "static indexed queue slice failed: calls=%0d/%0d r=%p",
             base_calls, width_calls, r);

    r = q[2:2];
    if (r.size() != 1 || r[0] != 30)
      $fatal(1, "single-element slice failed: r=%p", r);

    r = q[3:1];
    if (r.size() != 0)
      $fatal(1, "reversed slice was not empty: r=%p", r);

    r = q[-2:1];
    if (r.size() != 2 || r[0] != 10 || r[1] != 20)
      $fatal(1, "negative lower bound did not clamp: r=%p", r);

    r = q[3:99];
    if (r.size() != 2 || r[0] != 40 || r[1] != 50)
      $fatal(1, "upper bound did not clamp: r=%p", r);

    r = q[99:100];
    if (r.size() != 0)
      $fatal(1, "wholly out-of-range slice was not empty: r=%p", r);

    // Signedness is part of an integral bound's value. In particular, an
    // unsigned one-bit 1 is +1, while a signed one-bit 1 is -1.
    one_bit = 1'b1;
    r = q[one_bit:one_bit];
    if (r.size() != 1 || r[0] != 20)
      $fatal(1, "unsigned one-bit bound was treated as negative: r=%p", r);
    r = q[0:one_bit];
    if (r.size() != 2 || r[0] != 10 || r[1] != 20)
      $fatal(1, "unsigned one-bit upper bound failed: r=%p", r);

    minus_one_bit = 1'b1;
    r = q[minus_one_bit:1];
    if (r.size() != 2 || r[0] != 10 || r[1] != 20)
      $fatal(1, "signed negative lower bound did not clamp: r=%p", r);
    r = q[0:minus_one_bit];
    if (r.size() != 0)
      $fatal(1, "signed negative upper bound was not empty: r=%p", r);

    // Values outside int64 still have unambiguous queue semantics: a huge
    // lower bound is beyond $, a huge upper bound clamps to $, and a huge
    // positive $ offset puts the upper bound below zero.
    huge_unsigned = '1;
    r = q[0:huge_unsigned];
    if (r.size() != 5 || r[4] != 50)
      $fatal(1, "large unsigned upper bound did not clamp: r=%p", r);
    r = q[huge_unsigned:$];
    if (r.size() != 0)
      $fatal(1, "large unsigned lower bound was not empty: r=%p", r);
    r = q[0:$-huge_unsigned];
    if (r.size() != 0)
      $fatal(1, "large unsigned offset was not empty: r=%p", r);

    huge_wide = '0;
    huge_wide[100] = 1'b1;
    r = q[0:huge_wide];
    if (r.size() != 5 || r[4] != 50)
      $fatal(1, "wide upper bound did not clamp: r=%p", r);
    r = q[huge_wide:$];
    if (r.size() != 0)
      $fatal(1, "wide lower bound was not empty: r=%p", r);
    r = q[0:$-huge_wide];
    if (r.size() != 0)
      $fatal(1, "wide offset was not empty: r=%p", r);
    r = q[0 +: huge_wide];
    if (r.size() != 5 || r[4] != 50)
      $fatal(1, "wide indexed width did not clamp without over-allocation: r=%p", r);

    // Do not saturate base and width independently before forming an indexed
    // endpoint: cancellation outside int64 can bring the endpoint back into
    // the live queue range.
    r = q[huge_wide -: (huge_wide + 128'd2)];
    if (r.size() != 5 || r[0] != 10 || r[4] != 50)
      $fatal(1, "wide unsigned indexed cancellation failed: r=%p", r);
    negative_wide = -$signed(huge_wide);
    r = q[negative_wide +: (huge_wide + 128'd2)];
    if (r.size() != 2 || r[0] != 10 || r[1] != 20)
      $fatal(1, "wide signed indexed cancellation failed: r=%p", r);

    // A signed magnitude just below INT64_MIN must saturate negative. It must
    // not wrap positive when used by colon, to-$, or $-offset queue ranges.
    below_int64 = -65'h08000000000000001;
    r = q[below_int64:1];
    if (r.size() != 2 || r[0] != 10 || r[1] != 20)
      $fatal(1, "below-int64 colon lower bound failed: r=%p", r);
    r = q[0:below_int64];
    if (r.size() != 0)
      $fatal(1, "below-int64 colon upper bound failed: r=%p", r);
    r = q[below_int64:$];
    if (r.size() != 5 || r[0] != 10 || r[4] != 50)
      $fatal(1, "below-int64 to-last lower bound failed: r=%p", r);
    r = q[0:$-below_int64];
    if (r.size() != 5 || r[0] != 10 || r[4] != 50)
      $fatal(1, "below-int64 last-offset bound failed: r=%p", r);

    negative_wide = -1;
    r = q[negative_wide:1];
    if (r.size() != 2 || r[0] != 10 || r[1] != 20)
      $fatal(1, "wide negative lower bound did not clamp: r=%p", r);
    r = q[0:negative_wide];
    if (r.size() != 0)
      $fatal(1, "wide negative upper bound was not empty: r=%p", r);
    r = q[0:$-negative_wide];
    if (r.size() != 5 || r[4] != 50)
      $fatal(1, "wide negative offset did not clamp: r=%p", r);

    unknown_bound = 'x;
    r = q[unknown_bound:3];
    if (r.size() != 0)
      $fatal(1, "unknown-bound slice was not empty: r=%p", r);
    r = q[0:unknown_bound];
    if (r.size() != 0)
      $fatal(1, "unknown upper-bound slice was not empty: r=%p", r);
    r = q[unknown_bound:$];
    if (r.size() != 0)
      $fatal(1, "unknown to-$ slice was not empty: r=%p", r);
    r = q[0:$-unknown_bound];
    if (r.size() != 0)
      $fatal(1, "unknown-offset slice was not empty: r=%p", r);
    r = q[0 +: unknown_bound];
    if (r.size() != 0)
      $fatal(1, "unknown indexed width was not empty: r=%p", r);
    r = q[unknown_bound +: 2];
    if (r.size() != 0)
      $fatal(1, "unknown indexed base was not empty: r=%p", r);
    r = q[0 +: 0];
    if (r.size() != 0)
      $fatal(1, "zero indexed width was not empty: r=%p", r);
    r = q[0 +: -1];
    if (r.size() != 0)
      $fatal(1, "negative indexed width was not empty: r=%p", r);
    r = q[-128'sd100 +: 128'd102];
    if (r.size() != 2 || r[0] != 10 || r[1] != 20)
      $fatal(1, "wide signed indexed base was not preserved: r=%p", r);
    r = q[one_bit +: 2];
    if (r.size() != 2 || r[0] != 20 || r[1] != 30)
      $fatal(1, "unsigned one-bit indexed base failed: r=%p", r);

    box = new;
    box.values = {10, 20, 30, 40, 50};
    boxes = {box};
    lo_calls = 0;
    hi_calls = 0;
    receiver_calls = 0;
    r = boxes[receiver_index()].values[next_lo():next_hi()];
    if (receiver_calls != 1 || lo_calls != 1 || hi_calls != 1 ||
        r.size() != 3 || r[0] != 20 || r[1] != 30 || r[2] != 40)
      $fatal(1, "receiver/bounds evaluated more than once: calls=%0d/%0d/%0d r=%p",
             receiver_calls, lo_calls, hi_calls, r);
    base_calls = 0;
    width_calls = 0;
    receiver_calls = 0;
    r = boxes[receiver_index()].values[next_base(3) -: next_width(3)];
    if (receiver_calls != 1 || base_calls != 1 || width_calls != 1 ||
        r.size() != 3 ||
        r[0] != 20 || r[1] != 30 || r[2] != 40)
      $fatal(1, "selected property indexed slice failed: calls=%0d/%0d/%0d r=%p",
             receiver_calls, base_calls, width_calls, r);
    base_calls = 0;
    width_calls = 0;
    receiver_calls = 0;
    if (boxes[receiver_index()].values
             [next_base(1) +: next_width(3)].size() != 3 ||
        receiver_calls != 1 || base_calls != 1 || width_calls != 1)
      $fatal(1, "method on selected-property queue slice failed: calls=%0d/%0d/%0d",
             receiver_calls, base_calls, width_calls);

    q = {};
    r = q[0:3];
    if (r.size() != 0)
      $fatal(1, "empty queue slice was not empty: r=%p", r);

    // Preserve the USBDEV expression shape: a variable queue slice is a
    // container-valued streaming operand, not a packed constant part select.
    stream_bits = {1,0,1,0, 1,1,0,0, 0,1,0,1, 0,0,1,1};
    stream_lo = 4;
    stream_hi = 11;
    stream_data = {<<{stream_bits[stream_lo:stream_hi]}};
    if (stream_data.size() != 1 || stream_data[0] != 8'ha3)
      $fatal(1, "streamed variable queue slice failed: data=%p", stream_data);

    $display("PASSED");
  end
endmodule
