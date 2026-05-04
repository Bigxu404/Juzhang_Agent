const { Client } = require('pg');
async function test(url) {
  const client = new Client({ connectionString: url, connectionTimeoutMillis: 5000 });
  try {
    await client.connect();
    console.log('Success:', url.split('@')[1]);
    await client.end();
  } catch (e) {
    console.log('Failed:', url.split('@')[1], 'Error:', e.message);
  }
}
async function main() {
  await test('postgresql://postgres.dcsrnikjcumaoqorlodg:t1213121.zx@aws-1-ap-south-1.pooler.supabase.com:6543/postgres');
  await test('postgresql://postgres.dcsrnikjcumaoqorlodg:t1213121.zx@aws-1-ap-south-1.pooler.supabase.com:5432/postgres');
}
main();
