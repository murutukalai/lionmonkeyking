
```
use std::collections::HashMap;

struct MyStruct {
    my_map: HashMap<String, Vec<i32>>,
}

impl MyStruct {
    fn new() -> MyStruct {
        MyStruct {
            my_map: HashMap::new(),
        }
    }

    fn push_value(&mut self, key: String, value: i32) {
        self.my_map.entry(key).or_insert(Vec::new()).push(value);
    }
}

fn main() {
    let mut my_struct = MyStruct::new();
    my_struct.push_value(String::from("first"), 10);
    my_struct.push_value(String::from("second"), 20);
    my_struct.push_value(String::from("first"), 30);

    println!("Map inside the struct: {:?}", my_struct.my_map);
}
```
