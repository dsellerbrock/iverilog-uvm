// A failed solve is transactional for shared static values, object copies do
// not duplicate/overwrite static storage, and the mode bit follows that same
// declaring cell rather than either object's instance slots.
class static_transaction_item;
  static rand int shared;
  rand int local_value;
  bit make_impossible;

  constraint values {
    shared == 17;
    local_value == 23;
    if (make_impossible)
      shared == 18;
  }
endclass

module test;
  initial begin
    static_transaction_item first;
    static_transaction_item second;
    static_transaction_item copied;
    int status;

    first = new;
    second = new;
    first.shared = 5;
    first.local_value = 6;
    if (first.randomize() !== 1
        || first.shared !== 17
        || second.shared !== 17
        || first.local_value !== 23)
      $fatal(1, "satisfiable randomize did not commit shared/local values");

    first.shared = 61;
    first.local_value = 62;
    first.make_impossible = 1;
    status = first.randomize();
    if (status !== 0)
      $fatal(1, "inconsistent static constraints were not UNSAT");
    if (static_transaction_item::shared !== 61
        || second.shared !== 61
        || first.local_value !== 62)
      $fatal(1, "UNSAT randomize changed shared or local storage");
    first.make_impossible = 0;

    first.shared = 77;
    first.local_value = 78;
    copied = new first;
    if (copied.local_value !== 78)
      $fatal(1, "shallow copy lost the ordinary instance property");
    if (static_transaction_item::shared !== 77
        || first.shared !== 77
        || second.shared !== 77
        || copied.shared !== 77)
      $fatal(1, "shallow copy duplicated or overwrote static storage");

    first.shared.rand_mode(0);
    if (second.shared.rand_mode() !== 0
        || copied.shared.rand_mode() !== 0)
      $fatal(1, "static rand_mode was not shared across a copy");
    copied.shared.rand_mode(1);
    if (first.shared.rand_mode() !== 1
        || second.shared.rand_mode() !== 1)
      $fatal(1, "static rand_mode did not re-enable through the copy");

    $display("PASSED");
  end
endmodule
