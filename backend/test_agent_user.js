const { Client } = require('pg');
async function test(url) {
  const client = new Client({ connectionString: url, connectionTimeoutMillis: 5000 });
  try {
    await client.connect();
    console.log('Success:', url);
    await client.end();
  } catch (e) {
    console.log('Failed:', url, 'Error:', e.message);
  }
}
async function main() {
  await test('postgresql://agent_user.dcsrnikjcumaoqorlodg:agent123@aws-0-ap-south-1.pooler.supabase.com:6543/postgres');
  await test('postgresql://agent_user.dcsrnikjcumaoqorlodg:agent123@aws-0-ap-south-1.pooler.supabase.com:5432/postgres');
}
main();
