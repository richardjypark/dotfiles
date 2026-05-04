import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";

const DEFAULT_TIMEOUT_MS = 180_000;
const RESULT_TYPE = "jj-fast-result";

type JjFastStatus = "success" | "error";

interface ParsedJjFastArgs {
	task: string;
	model?: string;
	error?: string;
}

function parseJjFastArgs(args: string): ParsedJjFastArgs {
	let rest = args.trim();
	if (!rest) return { task: "" };

	if (rest.startsWith("-- ")) {
		return { task: rest.slice(3).trim() };
	}

	for (const pattern of [/^--model=(\S+)\s*([\s\S]*)$/, /^--model\s+(\S+)\s*([\s\S]*)$/, /^-m\s+(\S+)\s*([\s\S]*)$/]) {
		const match = rest.match(pattern);
		if (!match) continue;
		const model = match[1];
		rest = match[2].trim();
		if (!rest) return { task: "", model, error: "Task is required after --model." };
		return { task: rest, model };
	}

	return { task: rest };
}

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
		const parsed = parseJjFastArgs(args);
		if (!parsed.task || parsed.error) {
			pi.sendMessage({
				customType: RESULT_TYPE,
				content:
					parsed.error ??
					"Usage: `/skill:jj [--model MODEL] <task>` or `/jj [--model MODEL] <task>`",
				display: true,
				details: { status: "error" },
			});
			return;
		}

		const command = parsed.model ? "env" : "jj-fast-agent";
		const commandArgs = parsed.model
			? [`JJ_FAST_AGENT_MODEL=${parsed.model}`, "jj-fast-agent", parsed.task]
			: [parsed.task];
		const result = await pi.exec(command, commandArgs, {
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
					? "Run the jj agent directly (optional: --model MODEL)"
					: "Override the jj skill with the fast jj agent (optional: --model MODEL)",
			handler: async (args, ctx) => {
				await runJjFast(args, ctx);
			},
		});
	}
}
