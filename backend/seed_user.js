const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const bcrypt = require('bcryptjs');

async function main() {
  const hashedPassword = await bcrypt.hash('password123', 10);
  await prisma.user.create({
    data: {
      id: '0a2472cc-a266-47a3-984d-1844cd882999',
      username: 'zhangxu',
      password: hashedPassword
    }
  });
  console.log("User seeded");
}
main().finally(() => prisma.$disconnect());
