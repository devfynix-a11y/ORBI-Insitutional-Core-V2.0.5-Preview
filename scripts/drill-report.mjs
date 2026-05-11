import fs from 'node:fs';
import path from 'node:path';

if (process.argv.includes('--help')) {
  console.log(`
ORBI disaster recovery drill report generator

Environment variables:
  ORBI_DRILL_TYPE
  ORBI_DRILL_ENV
  ORBI_DRILL_OWNER
  ORBI_DRILL_REVIEWER
  ORBI_DRILL_STATUS
  ORBI_DRILL_SUMMARY
  ORBI_DRILL_BACKUP_ID
  ORBI_DRILL_BACKUP_TIMESTAMP
  ORBI_DRILL_RESTORE_STARTED_AT
  ORBI_DRILL_RESTORE_COMPLETED_AT
  ORBI_DRILL_RECOVERY_TARGET_AT
  ORBI_DRILL_NOTES
  ORBI_DRILL_ACTION_ITEMS

Notes:
  - ORBI_DRILL_ACTION_ITEMS should be separated with ||
  - ORBI_DRILL_NOTES should be separated with ||
`.trim());
  process.exit(0);
}

const requiredFields = [
  'ORBI_DRILL_TYPE',
  'ORBI_DRILL_ENV',
  'ORBI_DRILL_OWNER',
  'ORBI_DRILL_REVIEWER',
  'ORBI_DRILL_STATUS',
  'ORBI_DRILL_SUMMARY',
];

const missing = requiredFields.filter((field) => !String(process.env[field] || '').trim());
if (missing.length > 0) {
  console.error(`Missing required environment variables: ${missing.join(', ')}`);
  process.exit(1);
}

const read = (name) => String(process.env[name] || '').trim();
const splitList = (value) => value.split('||').map((item) => item.trim()).filter(Boolean);
const now = new Date().toISOString();
const safeStamp = now.replace(/[:]/g, '-');

const report = {
  generatedAt: now,
  drillType: read('ORBI_DRILL_TYPE'),
  environment: read('ORBI_DRILL_ENV'),
  owner: read('ORBI_DRILL_OWNER'),
  reviewer: read('ORBI_DRILL_REVIEWER'),
  status: read('ORBI_DRILL_STATUS'),
  summary: read('ORBI_DRILL_SUMMARY'),
  backupId: read('ORBI_DRILL_BACKUP_ID'),
  backupTimestamp: read('ORBI_DRILL_BACKUP_TIMESTAMP'),
  restoreStartedAt: read('ORBI_DRILL_RESTORE_STARTED_AT'),
  restoreCompletedAt: read('ORBI_DRILL_RESTORE_COMPLETED_AT'),
  recoveryTargetAt: read('ORBI_DRILL_RECOVERY_TARGET_AT'),
  notes: splitList(read('ORBI_DRILL_NOTES')),
  actionItems: splitList(read('ORBI_DRILL_ACTION_ITEMS')),
};

const lines = [
  '# ORBI Drill Report',
  '',
  `Generated at: ${report.generatedAt}`,
  '',
  '## Summary',
  '',
  `- Drill type: ${report.drillType}`,
  `- Environment: ${report.environment}`,
  `- Owner: ${report.owner}`,
  `- Reviewer: ${report.reviewer}`,
  `- Status: ${report.status}`,
  `- Summary: ${report.summary}`,
  '',
  '## Restore Metadata',
  '',
  `- Backup ID: ${report.backupId || 'n/a'}`,
  `- Backup timestamp: ${report.backupTimestamp || 'n/a'}`,
  `- Restore started at: ${report.restoreStartedAt || 'n/a'}`,
  `- Restore completed at: ${report.restoreCompletedAt || 'n/a'}`,
  `- Recovery target at: ${report.recoveryTargetAt || 'n/a'}`,
  '',
  '## Notes',
  '',
];

if (report.notes.length === 0) {
  lines.push('- none recorded');
} else {
  for (const note of report.notes) lines.push(`- ${note}`);
}

lines.push('', '## Action Items', '');

if (report.actionItems.length === 0) {
  lines.push('- none recorded');
} else {
  for (const item of report.actionItems) lines.push(`- ${item}`);
}

lines.push('');

const outputDir = path.join(process.cwd(), 'artifacts', 'drills');
fs.mkdirSync(outputDir, { recursive: true });

const slug = `${report.drillType}-${report.environment}`.replace(/[^a-zA-Z0-9_-]+/g, '-').toLowerCase();
const outputPath = path.join(outputDir, `${safeStamp}-${slug}.md`);

fs.writeFileSync(outputPath, `${lines.join('\n')}\n`, 'utf8');

console.log(`Drill report written to ${outputPath}`);
