// Static class properties have one canonical value independent of the object
// handle used to reach them.  The VPI companion writes through view_a and
// reads the same members through view_b; this code then verifies the shared
// values through the class scope and through both object views.
module top;
  class payload_t;
    int marker;
    string label;
  endclass

  class shared_store;
    static logic [15:0] vec4_value;
    static real real_value;
    static string string_value;
    static payload_t shared_object;
    static int queue_values[$];
    static int dynamic_values[];
  endclass

  shared_store view_a;
  shared_store view_b;
  int vpi_failures = 0;

  initial begin
    int failures;

    failures = 0;
    view_a = new;
    view_b = new;

    shared_store::vec4_value = 16'h1234;
    shared_store::real_value = 1.25;
    shared_store::string_value = "from-sv";
    shared_store::shared_object = new;
    shared_store::shared_object.marker = 77;
    shared_store::shared_object.label = "payload-from-sv";

    shared_store::queue_values.delete();
    shared_store::queue_values.push_back(10);
    shared_store::queue_values.push_back(20);
    shared_store::dynamic_values = new[2];
    shared_store::dynamic_values[0] = 30;
    shared_store::dynamic_values[1] = 40;

    $static_class_storage_probe;

    failures += vpi_failures;
    if (shared_store::vec4_value !== 16'ha5xz ||
        view_a.vec4_value !== 16'ha5xz ||
        view_b.vec4_value !== 16'ha5xz) begin
      failures++;
      $display("FAILED SV vec4 class=%h a=%h b=%h",
               shared_store::vec4_value, view_a.vec4_value,
               view_b.vec4_value);
    end
    if (shared_store::real_value != 9.75 ||
        view_a.real_value != 9.75 || view_b.real_value != 9.75) begin
      failures++;
      $display("FAILED SV real class=%f a=%f b=%f",
               shared_store::real_value, view_a.real_value,
               view_b.real_value);
    end
    if (shared_store::string_value != "from-vpi" ||
        view_a.string_value != "from-vpi" ||
        view_b.string_value != "from-vpi") begin
      failures++;
      $display("FAILED SV string class='%s' a='%s' b='%s'",
               shared_store::string_value, view_a.string_value,
               view_b.string_value);
    end
    if (shared_store::shared_object == null ||
        view_a.shared_object == null || view_b.shared_object == null ||
        shared_store::shared_object.marker != 88 ||
        view_a.shared_object.marker != 88 ||
        view_b.shared_object.marker != 88 ||
        shared_store::shared_object.label != "payload-from-sv" ||
        view_a.shared_object.label != "payload-from-sv" ||
        view_b.shared_object.label != "payload-from-sv") begin
      failures++;
      $display("FAILED SV shared object");
    end
    if (shared_store::queue_values.size() != 2 ||
        view_a.queue_values.size() != 2 ||
        view_b.queue_values.size() != 2 ||
        shared_store::queue_values[1] != 222 ||
        view_a.queue_values[1] != 222 ||
        view_b.queue_values[1] != 222) begin
      failures++;
      $display("FAILED SV queue storage");
    end
    if (shared_store::dynamic_values.size() != 2 ||
        view_a.dynamic_values.size() != 2 ||
        view_b.dynamic_values.size() != 2 ||
        shared_store::dynamic_values[0] != 333 ||
        view_a.dynamic_values[0] != 333 ||
        view_b.dynamic_values[0] != 333) begin
      failures++;
      $display("FAILED SV dynamic-array storage");
    end

    if (failures == 0)
      $display("PASSED");
    else
      $display("FAILED total=%0d", failures);
    $finish(0);
  end
endmodule
