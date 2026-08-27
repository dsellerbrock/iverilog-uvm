// IEEE 1800-2017/2023 7.9.11: an associative-array default whose element is
// an unpacked struct is fallback state, not a shared mutable entry. Every
// absent read produces an independent value copy and does not create a key.
module main;
  typedef struct {
    int value;
    logic [7:0] tag;
  } entry_t;

  entry_t entries[int] =
      '{default:'{value:17, tag:8'ha1}};
  entry_t copied[int];
  entry_t first;
  entry_t second;
  bit failed;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    failed = 1'b0;

    check("default starts without entries",
          entries.size() == 0 && !entries.exists(1));
    first = entries[1];
    second = entries[2];
    check("absent reads receive complete fallback",
          first.value == 17 && first.tag === 8'ha1 &&
          second.value == 17 && second.tag === 8'ha1);
    check("absent reads do not insert",
          entries.size() == 0 &&
          !entries.exists(1) && !entries.exists(2));

    first.value = 91;
    first.tag = 8'hf1;
    check("absent read values are independent",
          second.value == 17 && second.tag === 8'ha1 &&
          entries[3].value == 17 && entries[3].tag === 8'ha1 &&
          !entries.exists(3));

    // Assigning an absent-read value to an element creates one explicit copy.
    // Mutating it must not change the fallback used by any other absent key.
    entries[4] = entries[40];
    entries[4].value = 44;
    entries[4].tag = 8'h44;
    check("explicit struct entry is independent from fallback",
          entries.size() == 1 && entries.exists(4) &&
          entries[4].value == 44 && entries[4].tag === 8'h44 &&
          entries[5].value == 17 && entries[5].tag === 8'ha1 &&
          !entries.exists(5));

    // Whole-map copying snapshots both explicit entries and the struct
    // fallback. Replacing the source then cannot mutate either part of copy.
    copied = entries;
    entries = '{default:'{value:21, tag:8'hb2}};
    check("replacement installs fresh struct fallback",
          entries.size() == 0 && !entries.exists(4) &&
          entries[4].value == 21 && entries[4].tag === 8'hb2);
    check("copy retains old entry and fallback",
          copied.size() == 1 && copied.exists(4) &&
          copied[4].value == 44 && copied[4].tag === 8'h44 &&
          copied[5].value == 17 && copied[5].tag === 8'ha1 &&
          !copied.exists(5));
    copied.delete(4);
    check("delete explicit reveals copied fallback",
          copied.size() == 0 && !copied.exists(4) &&
          copied[4].value == 17 && copied[4].tag === 8'ha1);

    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
