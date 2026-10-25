# IEEE 1800 text reviewed

- IEEE 1800-2023 §7.12.4, p. 177: the iterator-index method defaults to `index`; when that name conflicts with an item member, the array method can use an optional index argument to choose another identifier. The standard example uses `q = arr.find(item, iter_index) with (item.index != item.iter_index);`.
- IEEE 1800-2017 §7.12.4, p. 169: defines the iterator index method under the default `index` name, but does not include the 2023 optional renaming argument or example. Therefore, rejection of the second argument in `-g2017` is expected and is not a gap.
- IEEE 1800-2023 §7.12.5, p. 178: `map()` returns an unpacked array with the source range (or associative key set), replacing each element with the `with` expression; result element types are the expression's self-determined type. The clause's examples produce `{2,3,4}`, `{4,6,9}`, and `{1,1,0}`.
- IEEE 1800-2017 has no §7.12.5 `map()` clause; the method is new in 2023.
