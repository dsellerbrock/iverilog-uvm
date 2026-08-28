// IEEE 1800-2017/2023 6.24.1 and 7.6: an assignment-compatible
// queue/dynamic-array cast behaves like assignment to a temporary of the
// target type. Equivalent real elements exercise the general object-valued
// path rather than the legacy bit/logic bit-stream special case.
typedef real real_darray_t[];
typedef real real_queue_t[$];
typedef real bounded_real_queue_t[$:1];

module sv_container_explicit_cast;
  int errors;
  real source_q[$];
  real source_d[];
  real bounded_source_d[];
  real_darray_t cast_d;
  real_queue_t cast_q;
  bounded_real_queue_t bounded_q;
  real direct_cast_front;

  task check(input bit condition, input string what);
    if (!condition) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    source_q.push_back(1.25);
    source_q.push_back(2.5);
    source_d = new[3];
    source_d[0] = 3.75;
    source_d[1] = 4.5;
    source_d[2] = 5.25;
    bounded_source_d = new[2];
    bounded_source_d[0] = 7.25;
    bounded_source_d[1] = 8.5;

    cast_d = real_darray_t'(source_q);
    cast_q = real_queue_t'(source_d);
    bounded_q = bounded_real_queue_t'(bounded_source_d);
    direct_cast_front = real_queue_t'(source_d).pop_front();

    // Mutating either source after the cast must not change its temporary
    // value. push_back also proves that the reverse cast materialized a queue
    // rather than retaining a dynamic-array object behind the destination.
    source_q[0] = 10.0;
    source_d[0] = 30.0;
    cast_q.push_back(6.0);
    check(cast_d.size() == 2
          && cast_d[0] == 1.25 && cast_d[1] == 2.5,
          "queue-to-darray cast value and identity");
    check(cast_q.size() == 4
          && cast_q[0] == 3.75 && cast_q[3] == 6.0,
          "darray-to-queue cast value and runtime kind");
    check(bounded_q.size() == 2
          && bounded_q[0] == 7.25 && bounded_q[1] == 8.5,
          "cast honors bounded queue target");
    check(direct_cast_front == 3.75,
          "queue cast has queue runtime kind before any outer assignment");

    // Same-kind assignment-compatible typedef casts are clean as well.
    cast_d = real_darray_t'(cast_d);
    cast_q = real_queue_t'(cast_q);
    check(cast_d.size() == 2 && cast_q.size() == 4,
          "same-kind equivalent-element casts");

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
