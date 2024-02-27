mod bar;
mod foo;

// Not supported
// #[path = "alt_bim/mod.rs"]
// mod bim;

fn main() {
    println!("{:?}", std::env::args().collect::<Vec<String>>());
}

#[test]
fn test_1() {}

mod test {
    #[test]
    fn test_2() {}
}

/// Adds two numbers together.
///
/// # Examples
///
/// ```
/// assert_eq!(2+3, 5);
/// ```
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
