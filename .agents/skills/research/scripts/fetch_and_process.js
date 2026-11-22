#!/usr/bin/env node

/**
 * fetch_and_process.js
 *
 * Safely fetches data from a URL directly to the hard drive, bypassing the LLM context.
 * It immediately parses, sanitizes, and chunks the data to prevent Prompt Injections and
 * Context Bloat.
 */

import { existsSync, mkdirSync, writeFileSync, appendFileSync } from "fs";
import { execFileSync } from "child_process";
import { createHash } from "crypto";
import { join, basename } from "path";

// --- Configuration & Constants ---
const MAX_CHARS = 12000;
const MAX_BYTES = 5 * 1024 * 1024;
const FETCH_TIMEOUT_MS = 20000;

const SUSPICIOUS_PATTERNS = [
  /ignore all previous/i,
  /new instructions/i,
  /disregard/i,
  /you are now/i,
  /system prompt/i,
  /hidden instruction/i,
  /stop following/i,
  /forget your/i,
  /don't pay attention to/i,
  /reset your/i,
  /abandon your/i,
];

const HIDDEN_TEXT_PATTERNS = [
  /[\u200B-\u200D\uFEFF]/, // Zero-width characters (ZWSP, ZWNJ, ZWJ, BOM)
];

const GENERIC_NAMES = [
  "raw_data",
  "raw_findings",
  "data",
  "research",
  "info",
  "overview",
  "results",
  "output",
  "temp",
];

// --- Helper Functions ---

function scanForSuspiciousContent(content) {
  const findings = [];
  const normalized = content
    .normalize("NFKC")
    .replace(/[\u200B-\u200D\uFEFF]/g, "")
    .replace(/\s+/g, " ");

  SUSPICIOUS_PATTERNS.forEach((pattern) => {
    if (pattern.test(normalized)) {
      findings.push(`Instruction Override Attempt: ${pattern.toString()}`);
    }
  });

  return findings;
}

function splitIntoChunks(content) {
  const chunks = [];
  for (let offset = 0; offset < content.length; offset += MAX_CHARS) {
    chunks.push(content.slice(offset, offset + MAX_CHARS));
  }
  return chunks;
}

function sanitize(content) {
  return content.trim();
}

function updateOverview(
  outputDir,
  fileName,
  summary,
  researchName,
  isFirstPart,
) {
  const overviewPath = join(outputDir, "overview.md");
  const entry = `\n### ${basename(fileName, ".md")}\n- **Artifact:** [${fileName}](${fileName})\n- **Summary:** ${summary.substring(0, 200)}...\n`;

  if (isFirstPart || !existsSync(overviewPath)) {
    const header = `# Research Overview: ${researchName}\n\nThis file provides a rational structure and links to processed research data. Redundant information has been filtered out.\n`;
    writeFileSync(overviewPath, header + entry);
  } else {
    appendFileSync(overviewPath, entry);
  }
}

const Handlers = {
  json: (content) => {
    try {
      const parsed = JSON.parse(content);
      return JSON.stringify(parsed, null, 2);
    } catch (e) {
      throw new Error("Invalid JSON format");
    }
  },
  csv: (content) => {
    const lines = content.trim().split("\n");
    if (lines.length === 0) return "";
    const headers = lines[0].split(",").map((h) => h.trim());
    const rows = lines
      .slice(1)
      .map((line) => line.split(",").map((c) => c.trim()));

    let md = `| ${headers.join(" | ")} |\n`;
    md += `| ${headers.map(() => "---").join(" | ")} |\n`;
    rows.forEach((row) => {
      md += `| ${row.join(" | ")} |\n`;
    });
    return md;
  },
  html: (content) => {
    let cleaned = content
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
      .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, "");

    cleaned = cleaned
      .replace(/<h[1-6][^>]*>/gi, "\n\n")
      .replace(/<\/h[1-6]>/gi, "\n\n")
      .replace(/<br\s*\/?>(?=\S)/gi, "\n")
      .replace(/<[^>]*>?/gm, " ")
      .replace(/[ \t]+/g, " ")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
    return cleaned;
  },
  plain: (content) => content,
};

// --- Main Execution ---

const args = process.argv.slice(2);
if (args.length < 2) {
  console.error(
    "Usage: node .gemini/skills/research/scripts/fetch_and_process.js <url> <research-topic-name>",
  );
  process.exit(1);
}

const url = args[0];
const topicName = args[1];

if (GENERIC_NAMES.includes(topicName.toLowerCase())) {
  console.error(
    `Error: Generic topic name "${topicName}" detected. Please use a highly specific name (e.g., 'flutter_ssl_pinning').`,
  );
  process.exit(1);
}

const parsedUrl = new URL(url);
if (parsedUrl.protocol !== "https:") {
  console.error("Error: only HTTPS URLs are allowed");
  process.exit(1);
}

const sourceKey = createHash("sha256").update(url).digest("hex").slice(0, 12);
const outputDir = join(process.cwd(), "research", topicName, sourceKey);

if (!existsSync(outputDir)) {
  mkdirSync(outputDir, { recursive: true });
}

const rawFilePath = join(outputDir, "raw.txt");

function resolveUserAgent() {
  if (process.env.AGENT_RESEARCH_USER_AGENT) {
    return process.env.AGENT_RESEARCH_USER_AGENT;
  }
  const ghRepo = process.env.GITHUB_REPOSITORY;
  if (ghRepo) {
    return `agent-research/1.0 (+https://github.com/${ghRepo})`;
  }
  try {
    const remote = execFileSync("git", ["config", "--get", "remote.origin.url"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    if (remote) {
      const normalized = remote
        .replace(/^git@([^:]+):/, "https://$1/")
        .replace(/\.git$/, "");
      if (normalized.startsWith("https://") || normalized.startsWith("http://")) {
        return `agent-research/1.0 (+${normalized})`;
      }
    }
  } catch {
    // Fall back to generic User-Agent when git remote is unavailable.
  }
  return "agent-research/1.0";
}

async function fetchAndProcess() {
  try {
    console.log(`Fetching data from: ${url}`);

    const response = await fetch(url, {
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      headers: {
        "User-Agent": resolveUserAgent(),
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const declaredLength = Number(response.headers.get("content-length") || 0);
    if (declaredLength > MAX_BYTES) {
      throw new Error(`response exceeds ${MAX_BYTES} byte limit`);
    }
    const text = await response.text();
    if (Buffer.byteLength(text, "utf8") > MAX_BYTES) {
      throw new Error(`response exceeds ${MAX_BYTES} byte limit`);
    }

    const contentType = response.headers.get("content-type") || "";
    const metadata = {
      url,
      fetched_at: new Date().toISOString(),
      status: response.status,
      content_type: contentType,
      sha256: createHash("sha256").update(text).digest("hex"),
    };

    const findings = scanForSuspiciousContent(text);
    if (findings.length > 0) {
      const quarantinePath = join(outputDir, "QUARANTINED.json");
      writeFileSync(quarantinePath, JSON.stringify({ metadata, findings }, null, 2));
      throw new Error(`suspicious content quarantined at ${quarantinePath}`);
    }

    console.log(`Writing raw data to: ${rawFilePath}`);
    writeFileSync(rawFilePath, text);
    writeFileSync(join(outputDir, "provenance.json"), JSON.stringify(metadata, null, 2));

    // Detect format
    let format = "html";
    if (url.endsWith(".json") || contentType.includes("json")) {
      format = "json";
    } else if (url.endsWith(".csv") || contentType.includes("csv")) {
      format = "csv";
    } else if (url.endsWith(".md") || contentType.includes("markdown")) {
      format = "plain";
    }

    console.log(`Processing and sanitizing data (Format: ${format})...`);

    const handler = Handlers[format] || Handlers.plain;
    const filtered = handler(text);
    const chunks = splitIntoChunks(filtered);

    chunks.forEach((chunk, index) => {
      const sanitized = sanitize(chunk);
      const partSuffix = chunks.length > 1 ? `_part${index + 1}` : "";
      const outputFileName = `info${partSuffix}.md`;
      const finalPath = join(outputDir, outputFileName);

      writeFileSync(finalPath, sanitized);
      updateOverview(
        outputDir,
        outputFileName,
        sanitized.substring(0, 500),
        topicName,
        index === 0,
      );

      console.log(
        `Processed part ${index + 1}/${chunks.length}: ${outputFileName}`,
      );
    });

    console.log(`\nSuccessfully processed ${chunks.length} parts.`);
    console.log(`Overview updated: ${join(outputDir, "overview.md")}`);
  } catch (error) {
    console.error(`\n[!] Error during fetch and process: ${error.message}`);
    process.exit(1);
  }
}

fetchAndProcess();
