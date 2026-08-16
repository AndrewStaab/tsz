    #[test]
    fn export_default_class_function_property_constraints_see_instance_members() {
        let options = resolved_options_for_es2015_strict_test();
        let base = std::path::Path::new("/");
        let diagnostics = collect_test_diagnostics_with_options(
            &[(
                "/export-default-function-properties.ts",
                r#"
type MarkOf<R extends { readonly mark: unknown }> = R["mark"];
export default class Schema<T = any> {
  readonly mark!: T;

  static make = <R extends Schema>(
    build: (x: number) => MarkOf<R>,
  ): R => null as any;

  take = <R extends Schema>(
    build: (x: number) => MarkOf<R>,
  ): R => null as any;

  static makeFunction = function<R extends Schema>(
    build: (x: number) => MarkOf<R>,
  ): R {
    return null as any;
  };

  static makeExplicit = <R extends InstanceType<typeof Schema>>(
    build: (x: number) => MarkOf<R>,
  ): R => null as any;
}
"#,
            )],
            &options,
            base,
        );

        assert!(
            diagnostics.is_empty(),
            "export-default class name references inside function-valued property \
             signatures must see the class instance shape; got: {diagnostics:#?}"
        );
    }
