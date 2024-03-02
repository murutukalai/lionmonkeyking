#[derive(Debug, PartialEq)]
struct MyStruct {
    id: u32,
    name: String,
}

fn main() {
    let vec_of_structs = vec![
        MyStruct { id: 1, name: String::from("Alice") },
        MyStruct { id: 2, name: String::from("Bob") },
        MyStruct { id: 3, name: String::from("Charlie") },
    ];

    let search_id = 2;
    if let Some(found_struct) = vec_of_structs.iter().find(|s| s.id == search_id) {
        println!("Found struct: {:?}", found_struct);
    } else {
        println!("Struct not found");
    }
}
