import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";

const DEFAULT_TIMEOUT_MS = 180_000;
const RESULT_TYPE = "jj-fast-result";

export default function (pi: ExtensionAPI) {
	pi.registerMessageRenderer(RESULT_TYPE, (message, _options, theme) => {
		const details = (message.details ?? {}) as { status?: "success" | "error" };
		const title =
			details.status === "error"
				? theme.fg("error", theme.bold("jj-fast error"))
				: theme.fg("success", theme.bold("jj-fast"));
		const body = String(message.content ?? "").trim();
		return new Text(`${title}\n${body}`.trim(), 0, 0);
	});

	const runJjFast = async (args: string, ctx: ExtensionCommandContext) => {
		const task = args.trim();
		if (!task) {
			pi.sendMessage({
				customType: RESULT_TYPE,
				content: "Usage: `/skill:jj <task>` or `/jj <task>`",
				display: true,
				details: { status: "error" },
			});
			return;
		}

		const result = await pi.exec(
			"bash",
			[
				"-lc",
				'cd "$1" && shift && exec jj-fast-agent "$@"',
				"jj-fast-command",
				ctx.cwd,
				task,
			],
			{ timeout: DEFAULT_TIMEOUT_MS },
		);

		const content = (result.stdout || result.stderr || "(no output)").trim();
		pi.sendMessage({
			customType: RESULT_TYPE,
			content,
			display: true,
			details: { status: result.code === 0 ? "success" : "error" },
		});
	};

	for (const name of ["skill:jj", "jj"]) {
		pi.registerCommand(name, {
			description:
				name === "jj"
					? "Run the spark-backed jj agent directly"
					: "Override the jj skill with the spark-backed jj agent for lower latency",
			handler: async (args, ctx) => {
				await runJjFast(args, ctx);
			},
		});
	}
}
