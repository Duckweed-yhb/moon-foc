///|
test "half-period transition uses one shared five-column time axis" {
  let seq = [(4, 0.5), (2, 0.5)]
  assert_eq(timeline_of(seq, 1.0, 0, 5), "##...")
  assert_eq(timeline_of(seq, 1.0, 1, 5), "..###")
}
