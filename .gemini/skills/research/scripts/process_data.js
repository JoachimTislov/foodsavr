#!/usr/bin/env node

/**
 * process_data.js
 * 
 * Safely reads and processes fetched data from various formats.
 * Implements sanitization, chunked splitting, and advanced suspicious pattern detection
 * including hidden/styled text designed to bypass human observation.
 */

const fs = require('fs');
const path = require('path');

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

function scanForSuspiciousContent(content) {
  const findings = [];
  
  // Check for instruction override patterns
  SUSPICIOUS_PATTERNS.forEach(pattern => {
    if (pattern.test(content)) {
      findings.push(`Instruction Override Attempt: ${pattern.toString()}`);
    }
  });

  // Check for hidden/styled text patterns
  HIDDEN_TEXT_PATTERNS.forEach(pattern => {
    if (pattern.test(content)) {
      findings.push(`Hidden/Styled Text Detected: ${pattern.toString()}`);
    }
  });

  return findings;
}

/**
 * Splits content into chunks that respect line and character limits.
 */
function splitIntoChunks(content) {
  const lines = content.split('\n');
  const chunks = [];
  let currentChunkLines = [];
  let currentCharCount = 0;

  for (const line of lines) {
    // If adding this line exceeds limits, start a new chunk
    if (currentChunkLines.length >= MAX_LINES || (currentCharCount + line.length + 1) > MAX_CHARS) {
      if (currentChunkLines.length > 0) {
        chunks.push(currentChunkLines.join('\n'));
      }
      currentChunkLines = [line];
      currentCharCount = line.length + 1;
    } else {
      currentChunkLines.push(line);
      currentCharCount += line.length + 1;
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

/**
 * Redundancy Filter: Basic check for duplicate sentences or paragraphs.
 */
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
    // Simple heuristic for redundancy
    if (!seen.has(trimmed)) {
      uniqueLines.push(line);
      seen.add(trimmed);
    }
  }
  return uniqueLines.join('\n');
}

/**
 * Overview Generator: Updates or creates an overview.md for the research session.
 */
function updateOverview(outputDir, fileName, summary, researchName) {
  const overviewPath = path.join(outputDir, 'overview.md');
  const entry = `\n### ${path.basename(fileName, '.md')}\n- **Source:** [${fileName}](${fileName})\n- **Summary:** ${summary.substring(0, 200)}...\n`;

  if (!fs.existsSync(overviewPath)) {
    const header = `# Research Overview: ${researchName}\n\nThis file provides a rational structure and links to processed research data. Redundant information has been filtered out.\n`;
    fs.writeFileSync(overviewPath, header + entry);
  } else {
    fs.appendFileSync(overviewPath, entry);
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

const args = process.argv.slice(2);
if (args.length < 2) {
  console.log("Usage: node process_data.js <format> <file_path>");
  process.exit(1);
}

const format = args[0].toLowerCase();
const inputFilePath = path.resolve(args[1]);

const baseFileName = path.basename(inputFilePath, path.extname(inputFilePath));
const researchName = baseFileName; // The research name is the basename of the file

const projectRoot = process.cwd();
const outputDir = path.join(projectRoot, 'research', researchName);

if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

if (!fs.existsSync(inputFilePath)) {
  console.error(`Error: Input file not found at ${inputFilePath}`);
  process.exit(1);
}

const rawContent = fs.readFileSync(inputFilePath, 'utf8');

const findings = scanForSuspiciousContent(rawContent);

if (findings.length > 0) {
  process.stdout.write("WARNING: SUSPICIOUS CONTENT DETECTED\n");
  findings.forEach(finding => process.stdout.write(`- ${finding}\n`));
  process.stdout.write("\nPlease ask the user if this data is safe to process before proceeding.\n");
  process.stdout.write("----------------------------------------------------------------------\n");
}

const handler = Handlers[format] || Handlers.plain;
const filtered = filterRedundancy(handler(rawContent));
const chunks = splitIntoChunks(filtered);

chunks.forEach((chunk, index) => {
  const sanitized = sanitize(chunk);
  const partSuffix = chunks.length > 1 ? `_part${index + 1}` : '';
  const outputFileName = `${baseFileName}${partSuffix}.md`;
  const finalPath = path.join(outputDir, outputFileName);

  fs.writeFileSync(finalPath, sanitized);
  updateOverview(outputDir, outputFileName, sanitized.substring(0, 500), researchName);

  console.log(`Processed part ${index + 1}/${chunks.length}: ${outputFileName}`);
});

console.log(`\nSuccessfully processed ${chunks.length} parts.`);
console.log(`Overview updated: ${path.join(outputDir, 'overview.md')}`);