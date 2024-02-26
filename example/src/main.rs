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
