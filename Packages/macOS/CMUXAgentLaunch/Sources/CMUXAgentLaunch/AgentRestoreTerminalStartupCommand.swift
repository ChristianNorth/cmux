import Foundation

/// Builds the terminal startup command for a local agent restore.
public enum AgentRestoreTerminalStartupCommand {
    /// The restore command resolves the binding from the app-owned surface ID.
    public static let surfaceRestoreCommand =
        #"cmux restore --surface "$CMUX_SURFACE_ID""#

    /// Runs the restore as a foreground job, then returns to the user's login shell.
    ///
    /// The temporary zsh process is interactive so terminal signals target the
    /// restored agent job. The process does not read user startup files. The
    /// user's configured shell starts after the restored agent exits.
    public static func command(for restoreCommand: String) -> String? {
        let normalizedCommand = restoreCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCommand == surfaceRestoreCommand else { return nil }

        let script = [
            normalizedCommand,
            #"_cmux_login_shell="${SHELL:-/bin/zsh}""#,
            #"if [[ "${_cmux_login_shell:t}" == fish && -r "${CMUX_FISH_INTEGRATION_FILE:-}" ]]; then exec "$_cmux_login_shell" -il --init-command 'source "$CMUX_FISH_INTEGRATION_FILE"'; fi"#,
            #"exec -l "$_cmux_login_shell""#,
        ].joined(separator: "; ")

        return "/usr/bin/env /bin/zsh -fic \(shellSingleQuoted(script))"
    }

    private static func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
