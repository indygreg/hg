extern crate cc;

fn main() {
    cc::Build::new()
        .warnings(true)
        .file("src/sendfds.c")
        .file("src/sighandlers.c")
        .compile("procutil");
}
