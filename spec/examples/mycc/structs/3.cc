struct Point {
    int x;
    int y;
};

struct Rect {
    struct Point origin;
    int width;
    int height;
};

void test_structs() {
    struct Point p = {10, 20};
    struct Rect r = {{0, 0}, 100, 200};
    
    printf("rect: %d %d %d %d\n", 
           r.origin.x, r.origin.y, r.width, r.height);

    r.origin.x = 11;
    (&((&r)->origin))->x = 12;
    int *wp = &r.width;
    *wp = 101;
    r.height = 202;

    printf("rect2: %d %d %d %d\n", 
           r.origin.x, r.origin.y, r.width, r.height);

}

int main() {
    test_structs();    
    return 0;
}
