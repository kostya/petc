struct Node {
    int v;
    struct Node *next;
};

void print_list(struct Node *node) {
    if (!node) return;
    printf("%d\n", node->v);
    print_list(node->next);
}

int main() {
    struct Node n3 = {3, 0};
    struct Node n2 = {2, &n3};
    struct Node n1 = {1, &n2};
    print_list(&n1);
    return 0;
}
