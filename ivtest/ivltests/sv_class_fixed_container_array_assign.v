// IEEE 1800-2017/2023 7.6, 10.9: assigning a whole fixed unpacked array whose
// elements are queues / associative arrays to a class property copies every
// element by value. OpenTitan flash_ctrl does `mp_info_regions = mp_info_pages;`.
// The code generator refused the whole-array store.
class holder;
  int q[2][$];
  bit aa[2][int];
endclass

module main;
  holder a, b;
  int local_q[2][$];
  int errors;
  initial begin
    a = new; b = new;
    b.q[0].push_back(1); b.q[1].push_back(2); b.q[1].push_back(3);
    b.aa[0][5] = 1; b.aa[1][6] = 1; b.aa[1][7] = 1;

    a.q = b.q;
    a.aa = b.aa;
    if (a.q[0].size() !== 1 || a.q[1].size() !== 2 || a.q[1][1] !== 3) begin
      $display("FAILED queue copy %p", a.q); errors++;
    end
    if (a.aa[0].num() !== 1 || a.aa[1].num() !== 2 || !a.aa[1].exists(7)) begin
      $display("FAILED assoc copy"); errors++;
    end

    // Value semantics: later changes to the source must not reach the copy.
    b.q[0].push_back(9);
    b.aa[0][99] = 1;
    if (a.q[0].size() !== 1 || a.aa[0].num() !== 1) begin
      $display("FAILED copy aliased its source"); errors++;
    end

    // Assignment from a module-level array of queues.
    local_q[1].push_back(4);
    a.q = local_q;
    if (a.q[0].size() !== 0 || a.q[1].size() !== 1 || a.q[1][0] !== 4) begin
      $display("FAILED assignment from a module array %p", a.q); errors++;
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
