// Regression: the `inside` operator has RELATIONAL precedence (IEEE 1800-2017
// Table 11-2) — above ==, &&, ||. iverilog declared K_inside at ternary level,
// so `a || b inside {s}` wrongly parsed as `(a || b) inside {s}` and
// `a && b inside {s}` as `(a && b) inside {s}`.
//
// This was the OpenTitan d_error root cause: cip_base_scoreboard predicates
//   is_tl_access_mapped_addr: `is_mem_addr(..) || norm_addr inside {csr_addrs}`
//   is_tl_access_unsupported_byte_wr: `!byte_en && opcode inside {..} && ..`
// mis-parsed, so valid CSR accesses were predicted as unmapped / byte-write
// errors -> false d_error scoreboard mismatches.

module top;
  initial begin
    int q[$];
    int x = 8;
    int errors = 0;
    q.push_back(0); q.push_back(4); q.push_back(8);

    // || : 0 || (8 inside {..8..}) = 1   (buggy parse gave (0||8) inside = 0)
    if (!(1'b0 || x inside {q}))           begin $display("FAIL or-right"); errors++; end
    // && : 1 && (8 inside {..}) = 1       (buggy: (1&&8) inside {..} = 0)
    if (!(1'b1 && x inside {q}))           begin $display("FAIL and-right"); errors++; end
    // inside above == : (8 inside {q}) == 1  -> 1==1 -> but `8 inside {q} == 1`
    //   parses as 8 inside {q} (==1 folded): check both sides explicitly
    if (!(x inside {q} && 1'b1))           begin $display("FAIL and-left"); errors++; end
    // negative case must remain 0 (not absorbed by precedence)
    if (1'b0 || 9 inside {q})              begin $display("FAIL or-right-neg"); errors++; end
    // mix with == : inside binds tighter than == ; 8 inside {q} is 1, 1==1
    if (!((x inside {q}) == 1'b1))         begin $display("FAIL eq"); errors++; end

    if (errors==0) $display("PASS");
    else $display("inside_operator_precedence_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
