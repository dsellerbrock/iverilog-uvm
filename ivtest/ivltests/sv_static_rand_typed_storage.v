// Every access form for a static class property must reach the declaring
// class-scope variable. Exercise each vvp_cobject value family beside direct
// C::property access and through two independent object handles.
typedef class mutual_storage_b;

class mutual_storage_a;
  mutual_storage_b peer;
endclass

class mutual_storage_b;
  mutual_storage_a peer;
endclass

class typed_payload;
  int marker;
endclass

class typed_static_holder;
  static logic [7:0] bits;
  static real ratio;
  static string text;
  static typed_payload object_value;
  static int queue_value[$];
  static int dynamic_value[];
  static int associative_value[string];
  static int nested_associative_value[string][$];
  static real real_words[2:4];
  static string string_words[4:2];
  static typed_payload object_words[2:4];
endclass

module test;
  initial begin
    typed_static_holder first;
    typed_static_holder second;
    typed_payload payload_a;
    typed_payload payload_b;
    int source_dynamic[];
    int source_queue[$];
    int source_associative[string];
    int source_nested_associative[string][$];
    int observed_nested_associative[string][$];
    int observed_nested_again[string][$];
    mutual_storage_a cycle_a;
    mutual_storage_b cycle_b;

    first = new;
    second = new;
    cycle_a = new;
    cycle_b = new;
    cycle_a.peer = cycle_b;
    cycle_b.peer = cycle_a;
    if (cycle_a.peer !== cycle_b || cycle_b.peer !== cycle_a)
      $fatal(1, "mutual declared class-handle metadata changed values");

    typed_static_holder::bits = 8'h5a;
    if (first.bits !== 8'h5a || second.bits !== 8'h5a)
      $fatal(1, "direct vec4 write was not shared");
    first.bits = 8'b10xz_01zx;
    if (typed_static_holder::bits !== 8'b10xz_01zx
        || second.bits !== 8'b10xz_01zx)
      $fatal(1, "object-view vec4 write lost four-state data");

    typed_static_holder::ratio = 1.25;
    if (first.ratio != 1.25 || second.ratio != 1.25)
      $fatal(1, "direct real write was not shared");
    second.ratio = -7.5;
    if (typed_static_holder::ratio != -7.5 || first.ratio != -7.5)
      $fatal(1, "object-view real write was not shared");

    typed_static_holder::text = "direct";
    if (first.text != "direct" || second.text != "direct")
      $fatal(1, "direct string write was not shared");
    first.text = "member";
    if (typed_static_holder::text != "member" || second.text != "member")
      $fatal(1, "object-view string write was not shared");

    payload_a = new;
    payload_a.marker = 17;
    first.object_value = payload_a;
    if (typed_static_holder::object_value.marker !== 17
        || second.object_value.marker !== 17)
      $fatal(1, "object handle write was not shared");
    payload_b = new;
    payload_b.marker = 29;
    typed_static_holder::object_value = payload_b;
    if (first.object_value.marker !== 29
        || second.object_value.marker !== 29)
      $fatal(1, "direct object handle write was not shared");

    typed_static_holder::queue_value.delete();
    first.queue_value.push_back(31);
    first.queue_value.push_back(32);
    second.queue_value[0] = 41;
    if (typed_static_holder::queue_value.size() !== 2
        || typed_static_holder::queue_value[0] !== 41
        || typed_static_holder::queue_value[1] !== 32
        || first.queue_value[0] !== 41)
      $fatal(1, "queue storage was not shared");

    first.dynamic_value = new[3];
    typed_static_holder::dynamic_value[0] = 51;
    second.dynamic_value[1] = 52;
    first.dynamic_value[2] = 53;
    if (typed_static_holder::dynamic_value.size() !== 3
        || second.dynamic_value[0] !== 51
        || typed_static_holder::dynamic_value[1] !== 52
        || second.dynamic_value[2] !== 53)
      $fatal(1, "dynamic-array storage was not shared");

    typed_static_holder::associative_value.delete();
    first.associative_value["first"] = 61;
    typed_static_holder::associative_value["second"] = 62;
    second.associative_value["first"] = 71;
    if (typed_static_holder::associative_value.num() !== 2
        || typed_static_holder::associative_value["first"] !== 71
        || first.associative_value["second"] !== 62)
      $fatal(1, "associative-array storage was not shared");

    // Dynamic arrays, queues and associative arrays are value containers.
    // A whole assignment into static storage must not retain the source
    // container handle, including nested container values.
    source_dynamic = new[2];
    source_dynamic[0] = 81;
    source_dynamic[1] = 82;
    first.dynamic_value = source_dynamic;
    source_dynamic[0] = 981;
    if (second.dynamic_value[0] !== 81)
      $fatal(1, "static dynamic-array whole assignment aliased its source");

    source_queue.push_back(83);
    source_queue.push_back(84);
    second.queue_value = source_queue;
    source_queue[1] = 984;
    if (typed_static_holder::queue_value[1] !== 84)
      $fatal(1, "static queue whole assignment aliased its source");

    source_associative["key"] = 85;
    first.associative_value = source_associative;
    source_associative["key"] = 985;
    if (second.associative_value["key"] !== 85)
      $fatal(1, "static associative whole assignment aliased its source");

    source_nested_associative["key"].push_back(86);
    second.nested_associative_value = source_nested_associative;
    source_nested_associative["key"][0] = 986;
    observed_nested_associative = first.nested_associative_value;
    if (observed_nested_associative["key"][0] !== 86)
      $fatal(1, "nested static associative assignment aliased its source");
    observed_nested_associative["key"][0] = 87;
    observed_nested_again = second.nested_associative_value;
    if (source_nested_associative["key"][0] !== 986
        || observed_nested_again["key"][0] !== 86)
      $fatal(1, "nested static associative value copy was not independent");

    typed_static_holder::real_words[2] = 2.25;
    first.real_words[3] = 3.25;
    second.real_words[4] = 4.25;
    if (first.real_words[2] != 2.25
        || typed_static_holder::real_words[3] != 3.25
        || first.real_words[4] != 4.25)
      $fatal(1, "fixed real-array storage was not shared");

    typed_static_holder::string_words[4] = "four";
    first.string_words[3] = "three";
    second.string_words[2] = "two";
    if (second.string_words[4] != "four"
        || typed_static_holder::string_words[3] != "three"
        || first.string_words[2] != "two")
      $fatal(1, "fixed string-array storage was not shared");

    first.object_words[2] = payload_a;
    typed_static_holder::object_words[3] = payload_b;
    second.object_words[4] = payload_a;
    if (second.object_words[2].marker !== 17
        || first.object_words[3].marker !== 29
        || typed_static_holder::object_words[4].marker !== 17)
      $fatal(1, "fixed object-array storage was not shared");

    $display("PASSED");
  end
endmodule
