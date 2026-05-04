const { Client } = require('pg');
async function test(url) {
  const client = new Client({ connectionString: url, connectionTimeoutMillis: 5000 });
  try {
    await client.connect();
    console.log('Success:', url);
    await client.end();
  } catch (e) {
    console.log('Failed:', url.split('@')[1], 'Error:', e.message);
  }
}
async function main() {
  const regions = ['ap-south-1', 'ap-southeast-1', 'ap-northeast-1', 'eu-central-1', 'us-east-1', 'us-west-1'];
  for (const r of regions) {
    await test(`postgresql://postgres.dcsrnikjcumaoqorlodg:t1213121@aws-0-${r}.pooler.supabase.com:6543/postgres`);
  }
}
main();
