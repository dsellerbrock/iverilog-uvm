// IEEE 1800-2017 7.9.4: integral associative-array traversal follows the
// declared index type's numeric order, including signed two's-complement keys.
class signed_assoc_holder;
  int entries[int];
endclass

module main;
  typedef bit [31:0] unsigned_key_t;

  bit failed;
  int direct[int];
  int copied[int];
  int defaulted[int];
  int unique_indexes[$];
  int unsigned_entries[unsigned_key_t];
  signed_assoc_holder holder;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  task automatic check_automatic;
    int automatic_entries[int];
    int key;

    automatic_entries[-9] = 1;
    automatic_entries[0] = 2;
    automatic_entries[6] = 3;
    check("automatic first result", automatic_entries.first(key));
    check("automatic first key", key == -9);
    check("automatic next zero result", automatic_entries.next(key));
    check("automatic next zero key", key == 0);
    check("automatic next positive result", automatic_entries.next(key));
    check("automatic next positive key", key == 6);
    check("automatic next end", !automatic_entries.next(key));
  endtask

  initial begin
    int key;
    unsigned_key_t unsigned_key;
    int i;

    failed = 1'b0;

      // A direct signal uses signed order in both traversal directions.
    direct[-3] = 13;
    direct[0] = 20;
    direct[5] = 25;
    check("direct first result", direct.first(key));
    check("direct first key", key == -3);
    check("direct next zero result", direct.next(key));
    check("direct next zero key", key == 0);
    check("direct next positive result", direct.next(key));
    check("direct next positive key", key == 5);
    check("direct next end", !direct.next(key));
    check("direct last result", direct.last(key));
    check("direct last key", key == 5);
    check("direct prev zero result", direct.prev(key));
    check("direct prev zero key", key == 0);
    check("direct prev negative result", direct.prev(key));
    check("direct prev negative key", key == -3);
    check("direct prev end", !direct.prev(key));

      // A value copy retains all entries; traversal semantics come from the
      // copied receiver's declared type, not from its construction path.
    copied = direct;
    direct.delete(-3);
    check("copied first result", copied.first(key));
    check("copied first key", key == -3);
    check("source changed independently", direct.first(key) && key == 0);

      // The default-pattern opcode constructs a fresh associative object.
      // Its fallback remains separate from entries and signed traversal.
    defaulted = '{default: 77};
    check("default fallback", defaulted[-100] == 77);
    check("default starts empty", defaulted.num() == 0);
    defaulted[-4] = 31;
    defaulted[0] = 32;
    defaulted[4] = 33;
    check("default-created first result", defaulted.first(key));
    check("default-created first key", key == -4);
    check("default-created last result", defaulted.last(key));
    check("default-created last key", key == 4);

      // unique_index has a separate inline first/next lowering. Its result
      // queue follows associative traversal order, so assert each position to
      // make an accidental unsigned /v lowering observable.
    unique_indexes = defaulted.unique_index();
    check("signed unique_index size", unique_indexes.size() == 3);
    check("signed unique_index negative", unique_indexes[0] == -4);
    check("signed unique_index zero", unique_indexes[1] == 0);
    check("signed unique_index positive", unique_indexes[2] == 4);
    for (i = 0; i < unique_indexes.size(); i = i + 1)
      check("signed unique_index member", defaulted.exists(unique_indexes[i]));

      // A class property is an object-stack receiver rather than the direct
      // signal opcode shape.
    holder = new;
    holder.entries[-8] = 41;
    holder.entries[0] = 42;
    holder.entries[9] = 43;
    check("property first result", holder.entries.first(key));
    check("property first key", key == -8);
    check("property next zero result", holder.entries.next(key));
    check("property next zero key", key == 0);
    check("property next positive result", holder.entries.next(key));
    check("property next positive key", key == 9);
    check("property next end", !holder.entries.next(key));

      // Unsigned indices preserve the existing high-bit ordering.
    unsigned_entries[32'h8000_0000] = 51;
    unsigned_entries[32'h0000_0000] = 52;
    unsigned_entries[32'hffff_ffff] = 53;
    unsigned_entries[32'h0000_0003] = 54;
    check("unsigned first result", unsigned_entries.first(unsigned_key));
    check("unsigned first key", unsigned_key == 32'h0000_0000);
    check("unsigned next low result", unsigned_entries.next(unsigned_key));
    check("unsigned next low key", unsigned_key == 32'h0000_0003);
    check("unsigned next high result", unsigned_entries.next(unsigned_key));
    check("unsigned next high key", unsigned_key == 32'h8000_0000);
    check("unsigned next max result", unsigned_entries.next(unsigned_key));
    check("unsigned next max key", unsigned_key == 32'hffff_ffff);
    check("unsigned next end", !unsigned_entries.next(unsigned_key));
    check("unsigned last result", unsigned_entries.last(unsigned_key));
    check("unsigned last key", unsigned_key == 32'hffff_ffff);
    check("unsigned prev high result", unsigned_entries.prev(unsigned_key));
    check("unsigned prev high key", unsigned_key == 32'h8000_0000);
    check("unsigned prev low result", unsigned_entries.prev(unsigned_key));
    check("unsigned prev low key", unsigned_key == 32'h0000_0003);
    check("unsigned prev zero result", unsigned_entries.prev(unsigned_key));
    check("unsigned prev zero key", unsigned_key == 32'h0000_0000);
    check("unsigned prev end", !unsigned_entries.prev(unsigned_key));

    check_automatic();

    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
