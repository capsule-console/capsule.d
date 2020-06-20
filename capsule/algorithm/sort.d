module capsule.algorithm.sort;

public:

alias DefaultSortCompare = (a, b) => (a < b);

/// Sorts an array using a binary insertion sort.
auto sort(alias compare = DefaultSortCompare, T)(auto ref T values) {
    for(size_t i = 1; i < values.length; i++){
        size_t low = 0;
        size_t high = i;
        size_t mid = i / 2;
        while(true){
            if(!compare(values[i], values[mid])){
                low = mid + 1;
            }else{
                high = mid;
            }
            mid = low + ((high - low) / 2);
            if(low >= high) break;
        }
        if(mid < i){
            auto x = values[i];
            size_t j = i;
            while(j > mid){
                values[j] = values[j - 1];
                j--;
            }
            values[j] = x;
        }
    }
    return values;
}

/// Test the sorting function
unittest {
    int[] ints = [4, 7, 3, 0, 2, 5, 1, 6];
    ints.sort();
    assert(ints == [0, 1, 2, 3, 4, 5, 6, 7]);
    ints.sort!((a, b) => (a > b))();
    assert(ints == [7, 6, 5, 4, 3, 2, 1, 0]);
}
