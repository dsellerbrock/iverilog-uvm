// IEEE 1800-2017/2023 7.4.5, 7.6: a constant-width dynamic-array
// slice is a fixed-size unpacked-array value. The complete right-hand side
// must be captured before replacing the destination in a self-assignment.
typedef struct {
  int marker;
  bit [7:0] msg[];
  string label;
} vector_t;

class vector_holder;
  vector_t partial[];
  vector_t all_oob[];
endclass

class slice_handle;
  int value;
endclass

module test;
  int data[];
  int selected[];
  bit [7:0] bit_data[];
  bit [7:0] bit_selected[];
  logic [7:0] logic_data[];
  logic [7:0] logic_selected[];
  real real_data[];
  real real_selected[];
  string string_data[];
  string string_selected[];

  vector_t vectors[];
  vector_t vector_copy[];
  vector_holder holder;
  slice_handle handles[];
  slice_handle handle_selected[];

  initial begin
    data = new[3];
    data[0] = 11;
    data[1] = 22;
    data[2] = 33;

    selected = data[1:3];
    if (selected.size() != 3 || selected[0] != 22 || selected[1] != 33
        || selected[2] != 0) begin
      $display("FAILED: non-self/OOB slice size=%0d values='%0d,%0d,%0d'",
               selected.size(), selected[0], selected[1], selected[2]);
      $finish(1);
    end

    data = data[0:1];
    if (data.size() != 2 || data[0] != 11 || data[1] != 22) begin
      $display("FAILED: int self-slice size=%0d", data.size());
      $finish(1);
    end

`ifdef __ICARUS__
    // The generated source word must retain all 64 signed index bits. Both
    // constants alias element zero if truncated to the old 32-bit immediate.
    // Slang 11 currently restricts a dynamic-array index to signed 32-bit;
    // keep this Icarus code-generation regression explicit and leave the
    // shared IEEE-polarity portion below accepted by both tools.
    selected = data[64'sd4294967296:64'sd4294967296];
    if (selected.size() != 1 || selected[0] != 0) begin
      $display("FAILED: far-positive source index was truncated");
      $finish(1);
    end
    selected = data[-64'sd4294967296:-64'sd4294967296];
    if (selected.size() != 1 || selected[0] != 0) begin
      $display("FAILED: far-negative source index was truncated");
      $finish(1);
    end
`endif

    bit_data = new[1];
    bit_data[0] = 8'hc3;
    bit_selected = bit_data[1:1];
    if (bit_selected.size() != 1 || bit_selected[0] != 8'h00) begin
      $display("FAILED: explicit two-state OOB default slice");
      $finish(1);
    end

    logic_data = new[2];
    logic_data[0] = 8'h5a;
    logic_data[1] = 8'ha5;
    logic_selected = logic_data[1:2];
    if (logic_selected.size() != 2 || logic_selected[0] != 8'ha5
        || !$isunknown(logic_selected[1])) begin
      $display("FAILED: four-state OOB default slice");
      $finish(1);
    end

    real_data = new[3];
    real_data[0] = 1.25;
    real_data[1] = 2.5;
    real_data[2] = 3.75;
    real_selected = real_data[1:3];
    if (real_selected.size() != 3 || real_selected[0] != 2.5
        || real_selected[1] != 3.75 || real_selected[2] != 0.0) begin
      $display("FAILED: real nonzero-base slice");
      $finish(1);
    end

    string_data = new[3];
    string_data[0] = "zero";
    string_data[1] = "one";
    string_data[2] = "two";
    string_selected = string_data[1:3];
    if (string_selected.size() != 3 || string_selected[0] != "one"
        || string_selected[1] != "two" || string_selected[2] != "") begin
      $display("FAILED: string nonzero-base slice");
      $finish(1);
    end

    vectors = new[3];
    foreach (vectors[i]) begin
      vectors[i].marker = 100 + i;
      vectors[i].msg = new[2];
      vectors[i].msg[0] = 8'h10 + i;
      vectors[i].msg[1] = 8'h20 + i;
      vectors[i].label = $sformatf("vector-%0d", i);
    end

    vector_copy = vectors[1:2];
    if (vector_copy.size() != 2 || vector_copy[0].marker != 101
        || vector_copy[1].msg[1] != 8'h22
        || vector_copy[0].label != "vector-1") begin
      $display("FAILED: unpacked-struct non-self slice");
      $finish(1);
    end
    vector_copy[0].marker = 999;
    vector_copy[0].msg[0] = 8'hff;
    vector_copy[0].label = "changed";
    if (vectors[1].marker != 101 || vectors[1].msg[0] != 8'h11
        || vectors[1].label != "vector-1") begin
      $display("FAILED: unpacked-struct element was aliased");
      $finish(1);
    end


    // A value-struct default is represented by a lazily materialized object.
    // Preserve its prototype through a temporary and a class-property copy.
    holder = new();
    vector_copy = vectors[2:3];
    holder.partial = vector_copy;
    if (holder.partial.size() != 2 || holder.partial[0].marker != 102
        || holder.partial[0].msg[1] != 8'h22
        || holder.partial[0].label != "vector-2"
        || holder.partial[1].marker != 0
        || holder.partial[1].label != ""
        || holder.partial[1].msg.size() != 0) begin
      $display("FAILED: partial-OOB struct default through class property");
      $finish(1);
    end

`ifdef __ICARUS__
    // This index is greater than UINT_MAX. The object load must reject it
    // before its unsigned storage API can wrap it onto vectors[0].
    vector_copy = vectors[64'sd4294967296:64'sd4294967296];
    holder.all_oob = vector_copy;
    if (holder.all_oob.size() != 1 || holder.all_oob[0].marker != 0
        || holder.all_oob[0].label != ""
        || holder.all_oob[0].msg.size() != 0) begin
      $display("FAILED: far-positive all-OOB struct default through class property");
      $finish(1);
    end
`endif

    // Class elements remain handles: an in-range selection keeps identity,
    // while its out-of-range neighbour remains a null handle (no prototype).
    handles = new[2];
    handles[0] = new();
    handles[1] = new();
    handles[0].value = 7;
    handles[1].value = 8;
    handle_selected = handles[1:2];
    if (handle_selected.size() != 2 || handle_selected[0] != handles[1]
        || handle_selected[1] != null) begin
      $display("FAILED: class-handle slice identity/null default");
      $finish(1);
    end
    handle_selected[0].value = 88;
    if (handles[1].value != 88) begin
      $display("FAILED: selected class handle was cloned");
      $finish(1);
    end

    vectors = vectors[0:1];
    if (vectors.size() != 2 || vectors[0].marker != 100
        || vectors[1].marker != 101 || vectors[0].msg.size() != 2
        || vectors[1].msg[0] != 8'h11
        || vectors[1].label != "vector-1") begin
      $display("FAILED: HMAC-shaped unpacked-struct self-slice");
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
