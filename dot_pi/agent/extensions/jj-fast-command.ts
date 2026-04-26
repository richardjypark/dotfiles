import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";

const DEFAULT_TIMEOUT_MS = 180_000;
const RESULT_TYPE = "jj-fast-result";

type JjFastStatus = "success" | "error";

function formatJjFastOutput(
	stdout: string,
	stderr: string,
	status: JjFastStatus,
	code: number,
	killed: boolean,
): string {
	const out = stdout.trim();
	const err = stderr.trim();

	if (status === "success") {
		return out || err || "(no output)";
	}

	if (out && err) {
		return `${out}\n\nstderr:\n${err}`;
	}
	if (out || err) {
		return err || out;
	}
	return killed
		? `jj-fast-agent was killed after ${DEFAULT_TIMEOUT_MS / 1000}s.`
		: `jj-fast-agent failed with exit code ${code}.`;
}

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

		const result = await pi.exec("jj-fast-agent", [task], {
			cwd: ctx.cwd,
			timeout: DEFAULT_TIMEOUT_MS,
		});

		const status: JjFastStatus = result.code === 0 ? "success" : "error";
		const content = formatJjFastOutput(
			result.stdout,
			result.stderr,
			status,
			result.code,
			result.killed,
		);
		pi.sendMessage({
			customType: RESULT_TYPE,
			content,
			display: true,
			details: { status },
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
