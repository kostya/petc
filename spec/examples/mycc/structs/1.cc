struct Point {
    int x;
    int y;
};

void test_struct() {
    struct Point p;
    p.x = 10;
    p.y = 20;
    printf("Point: %d, %d\n", p.x, p.y);
}

void test_struct2() {
    struct Point p;
    p.x = 10;
    p.y = 20;

    struct Point *ptr;
    ptr = &p;

    ptr->x = 11;
    (*ptr).y = 12;

    printf("Point: %d, %d\n", p.x, p.y);
}

int main() {
    test_struct();
    test_struct2();
    return 0;
}
