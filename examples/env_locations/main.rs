#[test]
fn test() {
    // our source file should be readable
    let source_file = std::fs::read_to_string(env!("SOURCE_FILE")).unwrap();
    assert_eq!(source_file, "source\n");
    // our generated data file should be readable at run time and build time
    let generated_data = std::fs::read_to_string(env!("GENERATED_DATA_ROOT")).unwrap();
    let generated_data2 = include_str!(env!("GENERATED_DATA_ABS"));
    assert_eq!(generated_data, generated_data2);
    // and we should be able to read (and thus execute) our tool
    assert!(!std::fs::read(env!("SOME_TOOL")).unwrap().is_empty());
    assert!(!std::fs::read(env!("SOME_TOOL_PLURAL_SINGLE"))
        .unwrap()
        .is_empty());
    // multiple source files at once should also be readable
    for source_file in env!("SOME_FILES_PLURAL").split(' ') {
        assert!(!std::fs::read_to_string(source_file).unwrap().is_empty());
    }
}
