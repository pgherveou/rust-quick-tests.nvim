#[test]
fn foo_test() {}

#[cfg(feature = "foo")]
#[test]
fn foo_test_2() {}

/// ```
/// let a = 1;
/// let b = 2;
/// assert_eq!(example::add(a, b), 3);
/// ```
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
