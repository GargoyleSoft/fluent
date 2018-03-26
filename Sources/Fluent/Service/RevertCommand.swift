import Async
import Command
import Logging
import Service

/// Console `Command` for reverting migrations that have been previously prepared.
///
/// Add this `Command` to your `CommandConfig` to enable it.
///
///     var commandConfig = CommandConfig.default()
///     commandConfig.use(RevertCommand.self, as: "revert")
///     services.register(commandConfig)
///
/// Once added to your `CommandConfig`, you can call the command using the configured name, usually `"revert"`.
///
///     swift run Run revert
///
public final class RevertCommand: Command, Service {
    /// See `Command.arguments`
    public var arguments: [CommandArgument] { return [] }

    /// See `Command.options`
    public var options: [CommandOption] { return [
        CommandOption.flag(name: "all", short: "a", help: ["Reverts all migrations, not just the latest batch."]),
        CommandOption.flag(name: "yes", short: "y", help: ["Automatically revert migrations without asking for confirmation"])
    ]}

    /// See `Command.help`
    public var help: [String] { return [
        "Reverts migrations that have been previously prepared.",
        "By default, only the latest batch of migrations will be reverted."
    ]}

    /// Creates a new `RevertCommand`
    public init() {}

    /// See `Command.run(using:)`
    public func run(using context: CommandContext) throws -> Future<Void> {
        let migrations = try context.container.make(MigrationConfig.self)
        let logger = try context.container.make(Logger.self)
        context.console.confirmOverride = true

        if context.options["all"]?.bool == true {
            logger.info("Revert all migrations requested")
            logger.warning("This will revert all migrations for all configured databases")
            guard try context.console.confirm("Are you sure you want to revert all migrations?") == true else {
                throw FluentError(identifier: "cancelled", reason: "Migration revert cancelled", source: .capture())
            }

            return migrations.storage.map { (uid, migration) in
                return {
                    logger.info("Reverting all migrations on '\(uid)' database")
                    return migration.migrationRevertAll(on: context.container)
                }
            }.syncFlatten(on: context.container).map(to: Void.self) {
                logger.info("Succesfully reverted all migrations")
            }
        } else {
            logger.info("Revert last batch of migrations requested")
            logger.warning("This will revert the last batch of migrations for all configured databases")
            guard try context.console.confirm("Are you sure you want to revert the last batch of migrations?") == true else {
                throw FluentError(identifier: "cancelled", reason: "Migration revert cancelled", source: .capture())
            }

            return migrations.storage.map { (uid, migration) in
                return {
                    logger.info("Reverting last batch of migrations on '\(uid)' database")
                    return migration.migrationRevertBatch(on: context.container)
                }
            }.syncFlatten(on: context.container).map(to: Void.self) {
                logger.info("Succesfully reverted last batch of migrations")
            }
        }
    }
}
