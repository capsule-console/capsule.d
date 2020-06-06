module capsule.core.heap;

public:

alias DefaultHeapCompare = (a, b) => (a < b);

/// Implements a heap data structure, often used to represent a
/// priority queue.
/// https://github.com/python/cpython/blob/3.8/Lib/heapq.py#L140
struct Heap(T, alias compare = DefaultHeapCompare) {
    T[] elements;
    
    this(in size_t size) {
        this.reserve(size);
    }
    
    bool empty() const {
        return this.elements.length == 0;
    }
    
    size_t length() const {
        return this.elements.length;
    }
    
    void reserve(in size_t size) {
        this.elements.reserve(size);
    }
    
    void clear() {
        this.elements.length = 0;
    }
    
    auto top() {
        assert(!this.empty);
        return this.elements[0];
    }
    
    size_t push(T item) {
        const length = this.elements.length;
        this.elements ~= item;
        return this.siftDown(0, length);
    }
    
    T pop() {
        assert(!this.empty);
        auto last = this.elements[$ - 1];
        this.elements.length--;
        if(this.elements.length) {
            auto top = this.elements[0];
            this.elements[0] = last;
            this.siftUp(0);
            return top;
        }
        else {
            return last;
        }
    }
    
    T replace(T item) {
        assert(!this.empty);
        auto top = this.elements[0];
        this.elements[0] = item;
        this.siftUp(0);
        return top;
    }
    
    size_t siftDown(in size_t start, in size_t index) {
        auto item = this.elements[index];
        size_t i = index;
        while(i > start) {
            const parentIndex = (i - 1) / 2;
            auto parent = this.elements[parentIndex];
            if(compare(item, parent)) {
                this.elements[i] = parent;
                i = parentIndex;
            }
            else {
                break;
            }
        }
        this.elements[i] = item;
        return i;
    }
    
    size_t siftUp(in size_t index) {
        const size_t end = this.elements.length;
        size_t i = index;
        size_t child = (2 * i) + 1;
        auto item = this.elements[index];
        while(child < end) {
            const right = child + 1;
            if(right < end &&
                !compare(this.elements[child], this.elements[right])
            ) {
                child = right;
            }
            this.elements[i] = this.elements[child];
            i = child;
            child = (2 * i) + 1;
        }
        this.elements[i] = item;
        return this.siftDown(index, i);
    }
}

unittest {
    // Build a heap
    Heap!int heap;
    assert(heap.empty);
    assert(heap.length == 0);
    heap.push(5);
    assert(!heap.empty);
    assert(heap.length == 1);
    assert(heap.top == 5);
    heap.push(3);
    assert(heap.length == 2);
    assert(heap.top == 3);
    heap.push(7);
    assert(heap.length == 3);
    assert(heap.top == 3);
    heap.push(4);
    assert(heap.length == 4);
    assert(heap.top == 3);
    heap.push(8);
    assert(heap.length == 5);
    assert(heap.top == 3);
    // Pop everything
    assert(heap.pop() == 3);
    assert(heap.pop() == 4);
    assert(heap.pop() == 5);
    assert(heap.pop() == 7);
    assert(heap.pop() == 8);
    assert(heap.empty);
}
