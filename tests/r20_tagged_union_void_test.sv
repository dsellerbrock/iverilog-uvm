// R20 (roadmap): a `void` member in a `union tagged` did not parse at
// all -- IEEE 1800-2017 7.3.2 allows a tagged-union member of type
// `void`, a tag that carries no payload value.
//
//   typedef union tagged { void Inv; int Valid; } u_t;
//
// used to be a syntax error at the typedef. `void` is elaborated to a
// zero-payload marker member (struct_union_member in parse.y, plus
// void_type_t::elaborate_type_raw in elab_type.cc); the existing
// tagged-union constructor (`tagged TAG`) and companion-tag machinery
// (build_tagged_union_companion_set_ in elaborate.cc) then just work
// with it as one more member.
`timescale 1ns/1ps

module main;
  typedef union tagged { void Inv; int Valid; } u_t;
  u_t u;

  initial begin
    // T1: construct the void tag -- this is the original defect.
    u = tagged Inv;

    // T2: switch to a value-carrying tag and read it back.
    u = tagged Valid 42;
    if (u.Valid !== 42) begin
      $display("FAILED (1)");
      $finish(0);
    end

    // T3: switch back to the void tag after a value tag was active --
    // make sure re-tagging to void doesn't corrupt the union or the
    // companion tag tracking used by the existing case-matches support.
    u = tagged Inv;

    // T4: one more value round-trip after the void tag, to confirm the
    // union's storage/tag machinery is unharmed by the void member.
    u = tagged Valid 7;
    if (u.Valid !== 7) begin
      $display("FAILED (2)");
      $finish(0);
    end

    $display("PASSED");
    $finish(0);
  end
endmodule
