import Testing

// Hand-rolled entry point because `swift test` under the bare command line tools
// can't link its synthesized runner. Run with `bin/test` (or `swift run shunt-tests`).
@main struct Runner {
    static func main() async {
        await Testing.__swiftPMEntryPoint() as Never
    }
}
