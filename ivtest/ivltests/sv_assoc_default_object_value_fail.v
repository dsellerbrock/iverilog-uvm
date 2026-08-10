// An unpacked-struct associative value needs a fresh value-copy fallback on
// every absent read. Keep that legal but unsupported form loud until the
// object-backed aggregate path can provide those semantics.
module main;
  typedef struct {
    int value;
  } entry_t;

  entry_t entries[int] = '{default:'{value:17}};
endmodule
