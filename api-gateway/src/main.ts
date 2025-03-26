import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';

import { AppModule } from './app.module';

async function bootstrap () {
  const logger = new Logger('Bootstrap');
  const port = 3000;
  const app = await NestFactory.create(AppModule);

  await app.listen(3000, () => logger.log(`Api gateway running on port ${port}`));
}

bootstrap().catch((error) => {
  new Logger('Bootstrap').error(`Error: ${error instanceof Error ? `${error.message}` : 'Unknown error'}`);
  process.exit(1);
});
