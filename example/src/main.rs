mod bar;

fn main() {
    println!(
        "Called with args {:?}",
        std::env::args().collect::<Vec<_>>()
    );

    println!(
        "called with RUST_LOG: {:?}",
        std::env::vars()
            .collect::<Vec<_>>()
            .iter()
            .find(|(k, _)| k == "RUST_LOG")
    );
    println!();
}

#[test]
fn test_1() {
    let envs = std::env::vars()
        .filter(|(k, _)| k.starts_with("FOO"))
        .collect::<Vec<_>>();

    println!("called with env vars: {:?}", envs);
}

mod test {
    #[test]
    fn test_2() {}
}
