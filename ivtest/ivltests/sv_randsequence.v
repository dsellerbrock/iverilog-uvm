// M3B-2: randsequence (IEEE 1800-2017 18.17). Production-based random
// sequence generation, lowered by source-level expansion:
//   - a production sequence runs its items in order;
//   - a production with alternatives selects one (weighted by `:=`);
//   - code-block items execute; non-terminal items expand.
// Self-checking: deterministic-order checks for sequences/nesting, plus a
// statistical check that a 3:1 weight is honored.
module sv_randsequence;
  int order[$];
  int a = 0, b = 0;
  int errors = 0;

  initial begin
    // Sequencing + nesting: items run left-to-right, non-terminals expand.
    randsequence (main)
      main   : first second ;
      first  : { order.push_back(1); } ;
      second : sub_a sub_b ;
      sub_a  : { order.push_back(2); } ;
      sub_b  : { order.push_back(3); } ;
    endsequence
    if (order.size() != 3 || order[0] != 1 || order[1] != 2 || order[2] != 3) begin
      $display("FAILED order=%p exp '{1,2,3}", order); errors++;
    end

    // Weighted alternatives: `hi := 3 | lo := 1` -> hi ~3x as often as lo.
    for (int i = 0; i < 800; i++)
      randsequence (top)
        top : hi := 3 | lo := 1 ;
        hi  : { a++; } ;
        lo  : { b++; } ;
      endsequence
    if (a + b != 800) begin $display("FAILED total a+b=%0d exp 800", a+b); errors++; end
    // hi should dominate lo by roughly 3:1; allow a wide margin for RNG noise.
    if (!(a > b*2)) begin $display("FAILED weight not honored a=%0d b=%0d", a, b); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
