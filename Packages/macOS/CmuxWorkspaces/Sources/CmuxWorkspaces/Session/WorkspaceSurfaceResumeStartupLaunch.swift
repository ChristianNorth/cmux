/// Startup work produced for a restored surface resume binding.
public struct WorkspaceSurfaceResumeStartupLaunch: Equatable, Sendable {
    /// A command that starts with the terminal process.
    public let initialCommand: String?
    /// Input sent to the terminal's normally initialized shell.
    public let initialInput: String?

    /// Creates a startup-command launch.
    public static func command(_ command: String) -> Self {
        Self(initialCommand: command, initialInput: nil)
    }

    /// Creates a post-start input launch.
    public static func input(_ input: String) -> Self {
        Self(initialCommand: nil, initialInput: input)
    }
}
