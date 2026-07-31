/*
 * Multi-dimensional unpacked array parameters (IEEE 1800-2017 6.20, 7.4).
 *
 *   localparam int PiRotate [5][5] = '{ '{...}, ... };
 *   result[x][y] = state[PiRotate[x][y]][x];   // x,y are RUN-TIME ints
 *
 * Every expected value here is an ARITHMETIC expression of the loop
 * variables, never a second array lookup.  That matters: an oracle
 * built from a 1-D array parameter suffers the SAME direction bug as
 * the array under test, and for an ascending declaration the two
 * cancel exactly, so the check passes while both sides are wrong.
 *
 * The arithmetic was derived by hand from the pattern-to-index rule
 *
 *   pattern position (p0,p1,...) -> declared index
 *        i_k = left_k + p_k   when left_k <= right_k   (ascending)
 *        i_k = left_k - p_k   when left_k >  right_k   (descending)
 *
 * and confirmed against ordinary unpacked VARIABLES of the same shape
 * filled from the same pattern, which this compiler already supports:
 *
 *   int ASC[0:2][0:2]; ASC = '{'{1,2,3},'{4,5,6},'{7,8,9}};
 *      -> ASC[0][0]=1 ASC[1][2]=6 ASC[2][2]=9      (= x*3+y+1)
 *   int DSC[2:0][2:0]; DSC = same pattern
 *      -> DSC[2][2]=1 DSC[1][1]=5 DSC[0][0]=9      (= 9-(x*3+y))
 *   int NZ[1:3][2:4];  NZ  = same pattern
 *      -> NZ[1][2]=1  NZ[2][3]=5  NZ[3][4]=9       (= (x-1)*3+(y-2)+1)
 *
 * Flat 1-D array parameters are kept as a SECOND, weaker cross-check.
 */
module top;

   // ---------------- 2-D, three declaration styles ----------------
   localparam int ASC [0:2][0:2] = '{'{1,2,3},'{4,5,6},'{7,8,9}};
   localparam int DSC [2:0][2:0] = '{'{1,2,3},'{4,5,6},'{7,8,9}};
   localparam int NZ  [1:3][2:4] = '{'{1,2,3},'{4,5,6},'{7,8,9}};
   localparam int SZ  [3][3]     = '{'{1,2,3},'{4,5,6},'{7,8,9}};

   // Flat oracles, row-major, ascending from each dimension's LOW index.
   localparam int ASC_F [0:8] = '{1,2,3, 4,5,6, 7,8,9};
   localparam int DSC_F [0:8] = '{9,8,7, 6,5,4, 3,2,1};
   localparam int NZ_F  [0:8] = '{1,2,3, 4,5,6, 7,8,9};

   // ---------------- 3-D ----------------
   localparam int D3 [2][2][2] = '{'{'{1,2},'{3,4}},'{'{5,6},'{7,8}}};
   // descending outer, ascending inner
   localparam int D3M [1:0][0:1] = '{'{1,2},'{3,4}};

   // ---------------- packed element ----------------
   localparam logic [7:0] PK [0:1][0:2] = '{'{8'h11,8'h22,8'h33},
                                            '{8'h44,8'h55,8'h66}};
   localparam logic [7:0] PKD [1:0][2:0] = '{'{8'h11,8'h22,8'h33},
                                             '{8'h44,8'h55,8'h66}};

   // ---------------- parameter (not localparam) ----------------
   parameter int PARM [0:1][0:1] = '{'{10,20},'{30,40}};

   // ---------------- the OpenTitan table, verbatim ----------------
   localparam int PiRotate [5][5] = '{
      '{   0,   3,   1,   4,   2},
      '{   1,   4,   2,   0,   3},
      '{   2,   0,   3,   1,   4},
      '{   3,   1,   4,   2,   0},
      '{   4,   2,   0,   3,   1}
   };

   integer errors = 0;
   int x, y, z;

   task ck(input string tag, input int a, input int b, input int c,
           input int got, input int exp);
      begin
         if (got !== exp) begin
            $display("FAILED: %0s[%0d][%0d][%0d] = %0d, expected %0d",
                     tag, a, b, c, got, exp);
            errors = errors + 1;
         end
      end
   endtask

   initial begin
      // =============================================================
      // 1. CONSTANT indices, literal expected values.
      // =============================================================
      ck("ASCc", 0,0,0, ASC[0][0], 1);
      ck("ASCc", 1,2,0, ASC[1][2], 6);
      ck("ASCc", 2,2,0, ASC[2][2], 9);
      ck("DSCc", 2,2,0, DSC[2][2], 1);
      ck("DSCc", 1,1,0, DSC[1][1], 5);
      ck("DSCc", 0,0,0, DSC[0][0], 9);
      ck("NZc",  1,2,0, NZ[1][2],  1);
      ck("NZc",  2,3,0, NZ[2][3],  5);
      ck("NZc",  3,4,0, NZ[3][4],  9);
      ck("SZc",  0,0,0, SZ[0][0],  1);
      ck("SZc",  2,2,0, SZ[2][2],  9);
      ck("D3c",  1,0,1, D3[1][0][1], 6);
      ck("D3Mc", 1,0,0, D3M[1][0], 1);   // outer [1:0]: pos0 -> index 1
      ck("D3Mc", 0,1,0, D3M[0][1], 4);
      ck("PKc",  0,1,0, int'(PK[0][1]),  int'(8'h22));
      ck("PKDc", 1,2,0, int'(PKD[1][2]), int'(8'h11)); // both dims descend
      ck("PKDc", 0,0,0, int'(PKD[0][0]), int'(8'h66));
      ck("PARMc",0,1,0, PARM[0][1], 20);
      ck("PARMc",1,0,0, PARM[1][0], 30);
      ck("PIc",  1,3,0, PiRotate[1][3], 0);
      ck("PIc",  4,0,0, PiRotate[4][0], 4);

      // =============================================================
      // 2. RUN-TIME indices, ARITHMETIC expected values.
      //    x and y are written by the loop, so nothing folds.
      // =============================================================
      for (x = 0; x <= 2; x = x + 1)
        for (y = 0; y <= 2; y = y + 1) begin
           ck("ASCrt", x,y,0, ASC[x][y], x*3 + y + 1);
           ck("DSCrt", x,y,0, DSC[x][y], 9 - (x*3 + y));
           ck("SZrt",  x,y,0, SZ[x][y],  x*3 + y + 1);
        end
      for (x = 1; x <= 3; x = x + 1)
        for (y = 2; y <= 4; y = y + 1)
          ck("NZrt", x,y,0, NZ[x][y], (x-1)*3 + (y-2) + 1);

      // =============================================================
      // 3. RUN-TIME indices against the flat 1-D oracles (weaker, but
      //    it pins the row-major layout independently).
      // =============================================================
      for (x = 0; x <= 2; x = x + 1)
        for (y = 0; y <= 2; y = y + 1) begin
           ck("ASCvF", x,y,0, ASC[x][y], ASC_F[x*3 + y]);
           ck("DSCvF", x,y,0, DSC[x][y], DSC_F[x*3 + y]);
        end
      for (x = 1; x <= 3; x = x + 1)
        for (y = 2; y <= 4; y = y + 1)
          ck("NZvF", x,y,0, NZ[x][y], NZ_F[(x-1)*3 + (y-2)]);

      // =============================================================
      // 4. MIXED constant / run-time index.
      // =============================================================
      for (y = 0; y <= 2; y = y + 1) begin
         ck("ASCmixA", 1,y,0, ASC[1][y], 1*3 + y + 1);
         ck("DSCmixA", 1,y,0, DSC[1][y], 9 - (1*3 + y));
      end
      for (x = 0; x <= 2; x = x + 1) begin
         ck("ASCmixB", x,2,0, ASC[x][2], x*3 + 2 + 1);
         ck("DSCmixB", x,2,0, DSC[x][2], 9 - (x*3 + 2));
      end

      // =============================================================
      // 5. THREE dimensions at run time.
      // =============================================================
      for (x = 0; x <= 1; x = x + 1)
        for (y = 0; y <= 1; y = y + 1)
          for (z = 0; z <= 1; z = z + 1)
            ck("D3rt", x,y,z, D3[x][y][z], x*4 + y*2 + z + 1);
      // D3M[1:0][0:1]: pattern pos (p0,p1) -> index (1-p0, p1),
      // value p0*2+p1+1, so D3M[i][j] = (1-i)*2 + j + 1.
      for (x = 0; x <= 1; x = x + 1)
        for (y = 0; y <= 1; y = y + 1)
          ck("D3Mrt", x,y,0, D3M[x][y], (1-x)*2 + y + 1);

      // =============================================================
      // 6. Packed element: whole element and selects inside it.
      //    PK[0:1][0:2]:  PK[x][y]  = 8'h11 * (x*3 + y + 1)
   //    PKD[1:0][2:0]: pattern position (p0,p1) lands at index
   //                   (1-p0, 2-p1) with value 8'h11*(p0*3+p1+1),
   //                   so PKD[i][j] = 8'h11 * ((1-i)*3 + (2-j) + 1).
      // =============================================================
      for (x = 0; x <= 1; x = x + 1)
        for (y = 0; y <= 2; y = y + 1) begin
           ck("PKrt",  x,y,0, int'(PK[x][y]),      8'h11 * (x*3 + y + 1));
           ck("PKrtL", x,y,0, int'(PK[x][y][3:0]), (x*3 + y + 1));
           ck("PKrtH", x,y,0, int'(PK[x][y][7:4]), (x*3 + y + 1));
           ck("PKDrt", x,y,0, int'(PKD[x][y]),
              8'h11 * ((1-x)*3 + (2-y) + 1));
        end

      // =============================================================
      // 7. parameter (not localparam), run time.
      // =============================================================
      for (x = 0; x <= 1; x = x + 1)
        for (y = 0; y <= 1; y = y + 1)
          ck("PARMrt", x,y,0, PARM[x][y], (x*2 + y + 1) * 10);

      // =============================================================
      // 8. The OpenTitan construct: pi[x][y] = state[(x+3y)%5][x].
      // =============================================================
      for (x = 0; x < 5; x = x + 1)
        for (y = 0; y < 5; y = y + 1)
          ck("PIrt", x,y,0, PiRotate[x][y], (x + 3*y) % 5);

      begin : as_index
         logic [4:0][4:0][7:0] state, result;
         for (x = 0; x < 5; x = x + 1)
           for (y = 0; y < 5; y = y + 1)
             state[x][y] = 8'(x*5 + y + 1);
         for (x = 0; x < 5; x = x + 1)
           for (y = 0; y < 5; y = y + 1)
             result[x][y] = state[PiRotate[x][y]][x];
         for (x = 0; x < 5; x = x + 1)
           for (y = 0; y < 5; y = y + 1)
             ck("PIuse", x,y,0, int'(result[x][y]),
                int'(8'(((x + 3*y) % 5)*5 + x + 1)));
      end

      if (errors == 0)
        $display("PASSED");
      else
        $display("FAILED (%0d error(s))", errors);
   end

endmodule
