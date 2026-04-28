import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
async function main() {
  const user = await prisma.user.findFirst({ where: { username: 'zhangxu' }});
  console.log(user);
}
main().catch(console.error).finally(() => prisma.$disconnect());
