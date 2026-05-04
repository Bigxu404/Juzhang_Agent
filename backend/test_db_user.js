const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const jwt = require('jsonwebtoken');

async function main() {
  const users = await prisma.user.findMany({
    select: { id: true, username: true }
  });
  console.log("Users in DB:", users);

  if (users.length > 0) {
    const token = jwt.sign({ userId: users[0].id }, 'super-secret-key-for-dev');
    console.log("Token for first user:", token);
  }
}
main().finally(() => prisma.$disconnect());
