use std::collections::HashSet;

fn main() {
    let hash_set: HashSet<i32> = vec![1, 2, 3, 4, 5].into_iter().collect();
    let vec: Vec<i32> = vec![3, 4, 5, 6, 7];

    let mut union_set = hash_set.clone();
    for &element in &vec {
        union_set.insert(element);
    }

    println!("{:?}", union_set);
}
