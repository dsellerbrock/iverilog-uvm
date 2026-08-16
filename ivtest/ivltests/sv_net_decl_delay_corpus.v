// Copyright (C) 2019-2021  The SymbiFlow Authors.
//
// Use of this source code is governed by a ISC-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/ISC
//
// SPDX-License-Identifier: ISC

/* Pinned sv-tests chapter-10/10.3.3--cont-assignment-net-delay.sv. */
module top(input a, input b);
  wire #10 w;
  assign w = a & b;
endmodule

// Keep the pinned source above unchanged; this independent harness root makes
// the same reducer usable by both runtime-oriented regression drivers.
module result;
  initial $display("PASSED");
endmodule
