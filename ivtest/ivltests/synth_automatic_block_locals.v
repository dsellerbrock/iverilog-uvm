`begin_keywords "1800-2012"

module main;
  typedef struct packed {
    struct packed {
      logic value;
    } INIT;
  } storage_t;

  typedef struct packed {
    struct packed {
      logic next;
      logic load_next;
    } INIT;
  } combo_t;

  logic decoded = 1'b0;
  logic data = 1'b0;
  storage_t storage;
  combo_t combo;

  // PeakRDL-generated Caliptra register blocks use explicit automatic
  // temporaries inside always_comb. Their activation-frame allocation and
  // release are simulation bookkeeping, while these assignments are the
  // combinational hardware that synthesis must retain.
  always_comb begin
    automatic logic next_c;
    automatic logic load_next_c;

    next_c = storage.INIT.value;
    load_next_c = 1'b0;
    if (decoded) begin
      next_c = data;
      load_next_c = 1'b1;
    end

    combo.INIT.next = next_c;
    combo.INIT.load_next = load_next_c;
  end

  (* ivl_synthesis_off *)
  initial begin
    storage.INIT.value = 1'b1;
    #1;
    if ({combo.INIT.next, combo.INIT.load_next} !== 2'b10)
      $fatal(1, "default path failed: %b%b",
             combo.INIT.next, combo.INIT.load_next);

    decoded = 1'b1;
    data = 1'b0;
    #1;
    if ({combo.INIT.next, combo.INIT.load_next} !== 2'b01)
      $fatal(1, "write path failed: %b%b",
             combo.INIT.next, combo.INIT.load_next);

    data = 1'b1;
    #1;
    if ({combo.INIT.next, combo.INIT.load_next} !== 2'b11)
      $fatal(1, "updated write path failed: %b%b",
             combo.INIT.next, combo.INIT.load_next);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
