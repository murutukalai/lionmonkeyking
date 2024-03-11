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

```
use std::collections::HashSet;

fn main() {
    let set1: HashSet<i32> = [1, 2, 3, 4, 5].iter().cloned().collect();
    let set2: HashSet<i32> = [3, 4, 5, 6, 7].iter().cloned().collect();

    let union_set: HashSet<&i32> = set1.union(&set2).collect();

    println!("{:?}", union_set);
}
