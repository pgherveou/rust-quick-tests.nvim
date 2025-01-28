mod bar;

fn main() {
    println!(
        "Called main with args {:?}",
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

#[test]
fn test_2() {
    let envs = std::env::vars()
        .filter(|(k, _)| k.starts_with("FOO"))
        .collect::<Vec<_>>();

    println!("called with env vars: {:?}", envs);
}

#[test]
fn test() {
    let envs = std::env::vars()
        .filter(|(k, _)| k.starts_with("FOO"))
        .collect::<Vec<_>>();

    let args = std::env::args().collect::<Vec<_>>();

    println!("called with env vars: {envs:?}");
    println!("called with args: {args:?}");
}
