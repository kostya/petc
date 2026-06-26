struct Point {
    int x;
    int y;
};

void test_structs() {
    struct Point p = {10, 20};
    printf("point: %d %d\n", p.x, p.y);
    
    p.x = 30;
    printf("modified point: %d %d\n", p.x, p.y);

    struct Point p2 = {11, 21};
    &p2->x = 12;
    *(int *)((char *)(&p2) + 4) = 22;
    printf("wtf point: %d %d %d\n", &p2->y, p2.x, p2.y);
}

int main() {
	test_structs();
    
    return 0;
}
