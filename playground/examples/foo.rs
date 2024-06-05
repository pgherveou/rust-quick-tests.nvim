//cargo run --example foo
fn main() {
    // print argument
    let a = "hello world";
    println!("{:?}", std::env::args());
    println!("Hello, world!");
}
