mod foo;
mod bar;
fn main() {
    println!("{:?}", std::env::args().collect::<Vec<String>>());
}

#[test]
fn test_1(){
  
}

mod test {
    #[test]
    fn test_2(){
      
    }
}
