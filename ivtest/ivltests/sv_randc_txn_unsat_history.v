// A failed randomize call must not consume randc history.  The RNG is restored
// explicitly after the failure because IEEE value/history atomicity does not
// require an implementation to roll back random-generator state.
class randc_txn_unsat_item;
  randc bit [1:0] value;
endclass

module test;
  initial begin
    randc_txn_unsat_item subject;
    randc_txn_unsat_item control;
    string subject_state;
    string control_state;
    bit [1:0] before_failure;
    bit [3:0] seen;
    int status;

    subject = new;
    control = new;
    subject.srandom(32'h1357_2468);
    control.srandom(32'h1357_2468);
    for (int cycle = 0; cycle < 8; cycle++) begin
      seen = '0;
      for (int sample = 0; sample < 4; sample++) begin
        subject_state = subject.get_randstate();
        control_state = control.get_randstate();
        before_failure = subject.value;

        status = subject.randomize() with { 1'b0; };
        if (status !== 0)
          $fatal(1, "contradictory inline constraint did not return zero");
        if (subject.value !== before_failure)
          $fatal(1, "failed randomize changed the visible randc value");

        // With correct transactional history, subject and control again have
        // identical history and identical RNG state. With the old eager mark,
        // subject has already reserved the exact candidate control will emit.
        subject.set_randstate(subject_state);
        control.set_randstate(control_state);
        if (subject.randomize() !== 1 || control.randomize() !== 1)
          $fatal(1, "post-failure control randomize failed");
        if (subject.value !== control.value)
          $fatal(1, "UNSAT call leaked randc history");
        if (seen[subject.value])
          $fatal(1, "successful value repeated inside aligned cycle");
        seen[subject.value] = 1'b1;
      end
      if (seen !== 4'b1111)
        $fatal(1, "interleaved UNSAT calls consumed cycle entries");
    end

    $display("PASSED");
  end
endmodule
