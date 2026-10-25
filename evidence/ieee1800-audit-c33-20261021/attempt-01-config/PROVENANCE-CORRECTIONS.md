# Audit issue provenance corrections

The lead found that issues #876–#881 described `fb584a251` as “current main.” It is the pinned audit toolchain source SHA (`fb584a251dd4cc91e56a75be662ccd5ee05c64e9`); `origin/main` at probe time was `10f3a0a2509d0852c2556cb662fb0025121fb2d`, and the dirty audit checkout was `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`. Per lead direction, posted the same correction on each issue:

| Issue | Correction comment |
| --- | --- |
| #876 | [comment](https://github.com/dsellerbrock/iverilog-uvm/issues/876#issuecomment-6310267939) |
| #877 | [comment](https://github.com/dsellerbrock/iverilog-uvm/issues/877#issuecomment-6310268224) |
| #878 | [comment](https://github.com/dsellerbrock/iverilog-uvm/issues/878#issuecomment-6310268542) |
| #879 | [comment](https://github.com/dsellerbrock/iverilog-uvm/issues/879#issuecomment-6310268815) |
| #880 | [comment](https://github.com/dsellerbrock/iverilog-uvm/issues/880#issuecomment-6310269067) |
| #881 | [comment](https://github.com/dsellerbrock/iverilog-uvm/issues/881#issuecomment-6310269316) |

The conclusions are unchanged. The lead deferred corrections to older issues that used `cc25756d1` in the same way until a later checkpoint.
