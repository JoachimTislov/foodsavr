#!/usr/bin/env node

/**
 * fetch_and_process.js
 *
 * Safely fetches data from a URL directly to the hard drive, bypassing the LLM context.
 * It immediately parses, sanitizes, and chunks the data to prevent Prompt Injections and 
 * Context Bloat.
 */

import { existsSync, mkdirSync, writeFileSync, appendFileSync } from "fs";
import { join, basename } from "path";

// --- Configuration & Constants ---

const MAX_LINES = 500;
const MAX_CHARS = 20000;

const SUSPICIOUS_PATTERNS = [
  /ignore all previous/i,
  /new instructions/i,
  /disregard/i,
  /act as/i,
  /you are now/i,
  /system prompt/i,
  /hidden instruction/i,
  /stop following/i,
  /forget your/i,
  /don't pay attention to/i,
  /override/i,
  /reset your/i,
  /abandon your/i
];

const HIDDEN_TEXT_PATTERNS = [
  /display:\s*none/i,
  /visibility:\s*hidden/i,
  /opacity:\s*0/i,
  /font-size:\s*0/i,
  /color:\s*transparent/i,
  /position:\s*absolute;\s*left:\s*-\d{3,}/i, // Extreme off-screen positioning
  /clip:\s*rect\(0\s*0\s*0\s*0\)/i,
  /[\u200B-\u200D\uFEFF]/ // Zero-width characters (ZWSP, ZWNJ, ZWJ, BOM)
];

const GENERIC_NAMES = [
  "raw_data", "raw_findings", "data", "research", 
  "info", "overview", "results", "output", "temp"
];

// --- Helper Functions ---

function scanForSuspiciousContent(content) {
  const findings = [];
  
  SUSPICIOUS_PATTERNS.forEach(pattern => {
    if (pattern.test(content)) {
      findings.push(`Instruction Override Attempt: ${pattern.toString()}`);
    }
  });

  HIDDEN_TEXT_PATTERNS.forEach(pattern => {
    if (pattern.test(content)) {
      findings.push(`Hidden/Styled Text Detected: ${pattern.toString()}`);
    }
  });

  return findings;
}

function splitIntoChunks(content) {
  const lines = content.split('\n');
  const chunks = [];
  let currentChunkLines = [];

  for (const line of lines) {
    if (currentChunkLines.length >= MAX_LINES) {
      chunks.push(currentChunkLines.join('\n'));
      currentChunkLines = [line];
    } else {
      currentChunkLines.push(line);
    }
  }

  if (currentChunkLines.length > 0) {
    chunks.push(currentChunkLines.join('\n'));
  }

  return chunks;
}

function sanitize(content) {
  let sanitized = content;
  SUSPICIOUS_PATTERNS.forEach(pattern => {
    sanitized = sanitized.replace(pattern, "[REDACTED_POTENTIAL_INJECTION]");
  });
  return sanitized.trim();
}

function filterRedundancy(content) {
  const lines = content.split('\n');
  const uniqueLines = [];
  const seen = new Set();

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      uniqueLines.push(line);
      continue;
    }
    if (!seen.has(trimmed)) {
      uniqueLines.push(line);
      seen.add(trimmed);
    }
  }
  return uniqueLines.join('\n');
}

function updateOverview(outputDir, fileName, summary, researchName, isFirstPart) {
  const overviewPath = join(outputDir, 'overview.md');
  const entry = `\n### ${basename(fileName, '.md')}\n- **Source:** [${fileName}](${fileName})\n- **Summary:** ${summary.substring(0, 200)}...\n`;

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
      return "Error: Invalid JSON format.";
    }
  },
  csv: (content) => {
    const lines = content.trim().split('\n');
    if (lines.length === 0) return "";
    const headers = lines[0].split(',').map(h => h.trim());
    const rows = lines.slice(1).map(line => line.split(',').map(c => c.trim()));
    
    let md = `| ${headers.join(' | ')} |\n`;
    md += `| ${headers.map(() => '---').join(' | ')} |\n`;
    rows.forEach(row => {
      md += `| ${row.join(' | ')} |\n`;
    });
    return md;
  },
  html: (content) => {
    let cleaned = content
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');
    
    const hiddenElements = content.match(/<[^>]+style\s*=\s*["'][^"']*(display:\s*none|visibility:\s*hidden|font-size:\s*0)[^"']*["'][^>]*>.*?<\/[^>]+>/gi);
    if (hiddenElements) {
      process.stdout.write(`CRITICAL: Found ${hiddenElements.length} elements with explicit hidden styles.\n`);
    }

    cleaned = cleaned.replace(/<[^>]*>?/gm, ' ').replace(/\s+/g, ' ').trim();
    return cleaned;
  },
  plain: (content) => content
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

const rawDir = join(process.cwd(), "research", "raw");
const outputDir = join(process.cwd(), "research", topicName);

if (!existsSync(rawDir)) {
  mkdirSync(rawDir, { recursive: true });
}
if (!existsSync(outputDir)) {
  mkdirSync(outputDir, { recursive: true });
}

const rawFilePath = join(rawDir, `${topicName}.txt`);

async function fetchAndProcess() {
  try {
    console.log(`Fetching data from: ${url}`);

    const response = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const text = await response.text();

    console.log(`Writing raw data to: ${rawFilePath}`);
    writeFileSync(rawFilePath, text);

    // Detect format
    let format = "html";
    const contentType = response.headers.get("content-type") || "";
    if (url.endsWith(".json") || contentType.includes("json")) {
      format = "json";
    } else if (url.endsWith(".csv") || contentType.includes("csv")) {
      format = "csv";
    } else if (url.endsWith(".md") || contentType.includes("markdown")) {
      format = "plain";
    }

    console.log(`Processing and sanitizing data (Format: ${format})...`);

    const findings = scanForSuspiciousContent(text);
    if (findings.length > 0) {
      process.stdout.write("\nWARNING: SUSPICIOUS CONTENT DETECTED\n");
      findings.forEach(finding => process.stdout.write(`- ${finding}\n`));
      process.stdout.write("\nPlease verify the safety of this data.\n");
      process.stdout.write("----------------------------------------------------------------------\n");
    }

    const handler = Handlers[format] || Handlers.plain;
    const filtered = filterRedundancy(handler(text));
    const chunks = splitIntoChunks(filtered);

    chunks.forEach((chunk, index) => {
      const sanitized = sanitize(chunk);
      const partSuffix = chunks.length > 1 ? `_part${index + 1}` : '';
      const outputFileName = `info${partSuffix}.md`;
      const finalPath = join(outputDir, outputFileName);

      writeFileSync(finalPath, sanitized);
      updateOverview(outputDir, outputFileName, sanitized.substring(0, 500), topicName, index === 0);

      console.log(`Processed part ${index + 1}/${chunks.length}: ${outputFileName}`);
    });

    console.log(`\nSuccessfully processed ${chunks.length} parts.`);
    console.log(`Overview updated: ${join(outputDir, 'overview.md')}`);

  } catch (error) {
    console.error(`\n[!] Error during fetch and process: ${error.message}`);
    process.exit(1);
  }
}

fetchAndProcess();
 updated: ${join(outputDir, 'overview.md')}`);

  } catch (error) {
    console.error(`\n[!] Error during fetch and process: ${error.message}`);
    process.exit(1);
  }
}

fetchAndProcess();
