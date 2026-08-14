// IEEE 1800-2017 10.9: assignment-pattern replication and keyed forms.
module test;
  typedef struct packed { int a; int b; } packed_pair_t;
  typedef struct { int a; int b; } pair_t;
  typedef struct packed { int a; int b0; int b1; int b2; int b3; } nested_t;
  typedef struct { int a; int b[4]; } unpacked_nested_t;
  typedef int ascending_t [1:3];
  typedef int descending_t [3:1];

  localparam int Pick = 2;

  packed_pair_t packed_rep = '{2{7}};
  packed_pair_t type_over_default = '{default:1, int:2};
  packed_pair_t last_type_wins = '{int:0, int:1};
  packed_pair_t member_over_type = '{a:3, int:4, default:5};
  ascending_t ascending = '{1:11, default:22};
  descending_t descending = '{1:33, default:44};
  logic [1:3][7:0] packed_indexed = '{1:8'h11, default:8'h22};

  initial begin
    pair_t unpacked;
    nested_t nested[1:0][2:0];
    unpacked_nested_t unpacked_nested[1:0][2:0];

    unpacked = '{a:6, int:7, default:8};
    nested = '{2{'{3{'{1, 2, 3, 2, 3}}}}};
    unpacked_nested = '{2{'{3{'{9, '{2{10, 11}}}}}}};

    if (packed_rep.a != 7 || packed_rep.b != 7)
      $fatal(1, "packed struct replication failed");
    if (type_over_default.a != 2 || type_over_default.b != 2)
      $fatal(1, "type key did not override default");
    if (last_type_wins.a != 1 || last_type_wins.b != 1)
      $fatal(1, "last matching type key did not win");
    if (member_over_type.a != 3 || member_over_type.b != 4)
      $fatal(1, "member/type/default precedence failed");
    if (unpacked.a != 6 || unpacked.b != 7)
      $fatal(1, "unpacked struct keyed pattern failed");

    if (ascending[1] != 11 || ascending[2] != 22 || ascending[3] != 22)
      $fatal(1, "ascending declared-index key failed");
    if (descending[3] != 44 || descending[2] != 44 || descending[1] != 33)
      $fatal(1, "descending declared-index key failed");
    ascending = '{Pick:55, default:66};
    if (ascending[1] != 66 || ascending[2] != 55 || ascending[3] != 66)
      $fatal(1, "constant identifier index key failed");
    ascending = '{int:77, default:0};
    if (ascending[1] != 77 || ascending[2] != 77 || ascending[3] != 77)
      $fatal(1, "array type key failed");
    if (packed_indexed[1] != 8'h11 || packed_indexed[2] != 8'h22
        || packed_indexed[3] != 8'h22)
      $fatal(1, "packed array index key failed");

    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++) begin
        if (nested[i][j].a != 1)
          $fatal(1, "nested struct replication a failed");
        if (nested[i][j].b0 != 2 || nested[i][j].b1 != 3
            || nested[i][j].b2 != 2 || nested[i][j].b3 != 3)
          $fatal(1, "nested struct/array replication failed");
        if (unpacked_nested[i][j].a != 9
            || unpacked_nested[i][j].b[0] != 10
            || unpacked_nested[i][j].b[1] != 11
            || unpacked_nested[i][j].b[2] != 10
            || unpacked_nested[i][j].b[3] != 11)
          $fatal(1, "nested unpacked-struct/array replication failed");
      end

    $display("PASSED");
  end
endmodule
