// Canonical static class storage must present one VPI object behind direct
// class-scope access and every object-member view. Callback attachment uses
// that canonical object while cb_data.obj remains the view that registered.
module top;
  class payload_t;
    int marker;
  endclass

  class base_t;
    static logic [7:0] hidden = 8'h11;
  endclass

  class derived_t extends base_t;
    static logic [7:0] hidden = 8'h22;
  endclass

  class holder_t;
    base_t nested;
  endclass

  class store_t;
    static logic [7:0] vec_value;
    static real real_value;
    static string string_value;
    static payload_t object_value;
    static logic [7:0] vec_words[3:5];
    static real real_words[6:4];
    static string string_words[2:4];
    static payload_t object_words[5:3];

    logic [7:0] instance_vec;
    logic instance_scalar;
    logic [7:0] dynamic_four[];
  endclass

  store_t view_a;
  store_t view_b;
  payload_t payload_a;
  payload_t payload_b;
  derived_t derived_object;
  base_t base_view;
  holder_t holder;
  int vpi_failures;

  initial begin
    int failures;
    failures = 0;
    view_a = new;
    view_b = new;
    payload_a = new;
    payload_b = new;
    payload_a.marker = 10;
    payload_b.marker = 20;
    derived_object = new;
    base_view = derived_object;
    holder = new;
    holder.nested = derived_object;

    store_t::vec_value = 8'h12;
    store_t::real_value = 1.25;
    store_t::string_value = "initial";
    store_t::object_value = payload_a;
    store_t::vec_words[4] = 8'h34;
    store_t::real_words[5] = 2.5;
    store_t::string_words[3] = "initial-word";
    store_t::object_words[4] = payload_a;
    view_a.dynamic_four = new[1];
    view_a.dynamic_four[0] = 8'h44;

    $static_storage_cb_setup;
    #1;

    // First change comes from direct SystemVerilog access.
    store_t::vec_value = 8'h56;
    store_t::real_value = 3.5;
    store_t::string_value = "from-sv";
    store_t::object_value = payload_b;
    store_t::vec_words[4] = 8'h67;
    store_t::real_words[5] = 4.5;
    store_t::string_words[3] = "sv-word";
    store_t::object_words[4] = payload_b;
    #1;

    // Second change is written through view_a VPI handles. The companion
    // also exercises non-static scalar/vector and darray-word X/Z puts.
    $static_storage_cb_write;
    #1;
    $static_storage_cb_check;

    if (store_t::vec_value !== 8'b1010_zxzx ||
        view_a.vec_value !== 8'b1010_zxzx ||
        view_b.vec_value !== 8'b1010_zxzx) begin
      failures++;
      $display("FAILED static vec X/Z value");
    end
    if (store_t::real_value != 9.75 ||
        view_a.real_value != 9.75 || view_b.real_value != 9.75) begin
      failures++;
      $display("FAILED static real value");
    end
    if (store_t::string_value != "from-vpi" ||
        view_a.string_value != "from-vpi" ||
        view_b.string_value != "from-vpi") begin
      failures++;
      $display("FAILED static string value");
    end
    if (store_t::object_value != null || view_a.object_value != null ||
        view_b.object_value != null) begin
      failures++;
      $display("FAILED static object value");
    end

    if (store_t::vec_words[4] !== 8'b1010_zxzx ||
        view_b.vec_words[4] !== 8'b1010_zxzx ||
        store_t::real_words[5] != 10.5 ||
        view_b.real_words[5] != 10.5 ||
        store_t::string_words[3] != "vpi-word" ||
        view_b.string_words[3] != "vpi-word" ||
        store_t::object_words[4] != null ||
        view_b.object_words[4] != null) begin
      failures++;
      $display("FAILED fixed static word values");
    end

    if (view_a.instance_vec !== 8'b0101_xzxz ||
        view_a.instance_scalar !== 1'bz ||
        view_a.dynamic_four[0] !== 8'b1100_zzxx) begin
      failures++;
      $display("FAILED non-static/darray X/Z controls");
    end

    // Declared views select the base hidden property even when the live
    // object is derived, both at top level and through a nested property.
    if (base_t::hidden !== 8'h91 || derived_t::hidden !== 8'ha2 ||
        base_view.hidden !== 8'h91 || derived_object.hidden !== 8'ha2 ||
        holder.nested.hidden !== 8'h91) begin
      failures++;
      $display("FAILED declared-view hidden-property selection");
    end

    failures += vpi_failures;
    if (failures == 0)
      $display("PASSED");
    else
      $display("FAILED total=%0d", failures);
    $finish(0);
  end
endmodule
